--2025-04-07_0225A_dsMain.sql 

-- START BELOW
SET NOCOUNT ON;

drop table if exists #tempfinal
	DECLARE @rpPeriod		DATE = ?
	DECLARE @rpProject  	VARCHAR(10) = ?
	DECLARE @rpPeriodType  	VARCHAR(10) = ?
	DECLARE @rpPIEPCCC		VARCHAR(MAX)  = '0,1,2,3,4,5,6,7,9'  
	DECLARE @rpFilter		VARCHAR(10) = 'None'--'Activity' -- Or none
	DECLARE @rpActivity		VARCHAR(15) =  ''
	DECLARE @rpActivityVendor VARCHAR(100) = 'ALL'--'BLMAC'--'Black and Macdonald'       

	DECLARE @rpLevel1	INT = 1
	DECLARE @rpLevel2	INT = 1
	DECLARE @rpLevel3	INT = 21
	DECLARE @rpLevel4	INT = 8
	DECLARE @rpLevel5	INT = 9



/* Levels:
	1 = Not Applicable
	2 = Program
	3 = Bundle
	4 = Vendor
	5 = Unit
	6 = Project
	7 = PIEPCCC
	8 = Execution Window
	9 = Work Package
	10 = RFR Sub-Project
	11 = RFR Custom PIEPCCC
	12 = Area Manager
	13 = Area
	14 = Project Owner
	15 = Director
	16 = Department Manager
	17 = Project Manager
	18 = Section Manager
	19 = CSA
*/

DROP TABLE IF EXISTS #sp, #v, #vd, #e, #r, #rd


DECLARE @Live as DATE = (
	SELECT TOP (1) sp.SnapshotDate
	FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp
	WHERE sp.ActivityIsProcessed = 1
	AND sp.PeriodType = 'Daily'

	ORDER BY sp.SnapshotDate DESC
)

/*************************************************************************************/
-->> USED TO GET THE RFR CRITICAL PATH GROUPINGS
/*************************************************************************************/

SELECT r.* INTO #r FROM NPDW_Report.ebx.v_INV_TF_0069_OPG_WP_Lookup_Live r

SELECT DISTINCT
	 r.OPG_WP AS 'Activity_ID'
	,r.WP_Description AS 'Activity_Name'
	,CriticalPath = IIF(r.rfr_cr_filter = 'critical','Critical Path','Non-Critical Path')
INTO #rd
FROM #r r

WHERE r.OPG_WP IS NOT NULL
  AND r.project_no IN (@rpProject)

/*************************************************************************************/
-->> USED TO GET THE RFR CUSTOM GROUPINGS
/*************************************************************************************/
SELECT v.* INTO #v FROM NPDW_Report.ebx.v_INV_TF_0070_Vendor_WP_Lookup_Live v 

SELECT DISTINCT
	 v.OPG_WP AS 'Activity_ID'
	,v.WP_Description AS 'Activity_Name'
	,v.Sub_Project
	,v.descr_cpiep3c
	,v.Area
	,v.Area_Manager
INTO #vd 
FROM #v v

WHERE 
	v.OPG_WP IS NOT NULL
AND v.project_no IN (@rpProject)



/*************************************************************************************/
-->> USED TO GET THE PROJECT INFO
/*************************************************************************************/
SELECT
	 e.program_title	AS 'Program'
	,e.bundle_title		AS 'Bundle'
	,e.unit_title		AS 'Unit'
	,e.vendor
	,IIF(LEFT(e.project_desc, 5) = e.project_number, '', e.project_number + ' - ') + e.project_desc AS 'Project'
	--,e.project_number + ' - ' + e.project_desc AS 'Project'
	,e.project_number
	,e.project_owner
	,e.director_name			AS 'director'
	,e.department_manager_name	AS 'department_manager'
	,e.project_manager_name		AS 'project_manager'
	,e.section_manager_name		AS 'section_manager'
	,e.csa_name					AS 'csa'
INTO #e
FROM [NPDW_Report].[ebx].[v_dim_EPL_Project] e
WHERE e.project_number IN (@rpProject)


/*************************************************************************************/
-->> CREATING THE SNAPSHOT TABLE FOR WEEKS, MONTHS, QUARTERS, YEARS
/*************************************************************************************/
SELECT
	sp.SnapshotPeriod
,	sp.SnapshotDate
,	sp.PeriodType
,	sp.ActivityIsProcessed
INTO #sp
FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp

UNION ALL

SELECT
	 CASE 
		WHEN sp.SnapshotPeriod LIKE 'March%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q1'
		WHEN sp.SnapshotPeriod LIKE 'June%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q2'
		WHEN sp.SnapshotPeriod LIKE 'September%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q3'
		WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q4'
		ELSE NULL
	 END as SnapshotPeriod
	,sp.SnapshotDate 
	,'Quarter' as PeriodType
	,sp.ActivityIsProcessed
FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp

WHERE
	sp.PeriodType = 'Monthly'
AND	CASE 
		WHEN sp.SnapshotPeriod LIKE 'March%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q1'
		WHEN sp.SnapshotPeriod LIKE 'June%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q2'
		WHEN sp.SnapshotPeriod LIKE 'September%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q3'
		WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q4'
		ELSE NULL
	END IS NOT NULL

UNION ALL

SELECT
	 CASE 
		WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)
		ELSE NULL
	 END as SnapshotPeriod
	,sp.SnapshotDate 
	,'Year' as PeriodType
	,sp.ActivityIsProcessed
FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp
WHERE
	sp.PeriodType = 'Monthly'
AND	CASE 
		WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)
		ELSE NULL
	END IS NOT NULL


--one period before
DECLARE @rpLastPeriod as date 
SET @rpLastPeriod = ( SELECT MAX(a.SnapshotDate) FROM #sp a WHERE a.PeriodType = @rpPeriodType AND a.SnapshotDate < @rpPeriod )

DECLARE @rpLastPeriodWeek as varchar(8) 
SET @rpLastPeriodWeek = ( SELECT MAX(ww.WorkWeek) FROM NPDW.rpt.v_NR_WorkWeek ww WHERE ww.WWStartDate <= @rpLastPeriod )

DECLARE @rpPeriodWeek as varchar(8) 
SET @rpPeriodWeek = (SELECT MAX(ww.WorkWeek) FROM NPDW.rpt.v_NR_WorkWeek ww WHERE ww.WWStartDate <= @rpPeriod )


--Live Work Week
DECLARE @LiveDate as date
SET @LiveDate =	(SELECT MAX(a.SnapshotDate) FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod a WHERE a.PeriodType = 'Daily' AND a.ActivityIsProcessed = 1)

DECLARE @LiveWeek as varchar(8)
SET @LiveWeek = (SELECT a.WorkWeek FROM NPDW_Report.sabi.v_dim_0254_TimePhasePeriod a WHERE a.Date = @LiveDate)




IF @rpPeriod = @LiveDate AND @LiveDate <> (
	SELECT MAX(a.SnapshotDate) 
	FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod a 
	WHERE a.PeriodType = 'Weekly' AND a.ActivityIsProcessed = 1
)

BEGIN
	DROP TABLE IF EXISTS #final_d
	DROP TABLE IF EXISTS #L2LOE_d
	DROP TABLE IF EXISTS #l2l3_d
	DROP TABLE IF EXISTS #pb_d
	DROP TABLE IF EXISTS #cl_d
	DROP TABLE IF EXISTS #aa_d
	DROP TABLE IF EXISTS #dd_d
	DROP TABLE IF EXISTS #v_d	-- Earned
	DROP TABLE IF EXISTS #tt_d	-- MASTER TABLE | Planned | Forecast | Earned 


-->> There is a possibility that multiple work packages will have the same BR_L2WorkPackage coding. To ensure that level 3 activities are not duplicated when matching we use this logic to identify only a single work package for each BR_L2WorkPackage
; WITH a as
(
SELECT 
	 aa.Snapshot_Date
	,aa.BR_L2WorkPackage
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.Activity_Name
	,aa.Activity_ID+' - '+aa.Activity_Name as WorkPackage
	,aa.BR_NR_EXECUTION_WINDOWS_Val AS 'Window'
	,ROW_NUMBER() OVER (PARTITION BY aa.Snapshot_Date, aa.BR_L2WorkPackage ORDER BY aa.Activity_ID) as rn
	,aa.BR_CM_VENDOR_Val
FROM NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
WHERE
	aa.Snapshot_Date = @rpPeriod
AND	aa.BR_ProjectNumber IN (@rpProject)

UNION ALL

SELECT 
	 aa.Snapshot_Date
	,aa.BR_L2WorkPackage
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.Activity_Name
	,aa.Activity_ID + ' - ' + aa.Activity_Name as WorkPackage
	,aa.BR_NR_EXECUTION_WINDOWS_Val AS 'Window'
	,ROW_NUMBER() OVER (PARTITION BY aa.Snapshot_Date, aa.BR_L2WorkPackage ORDER BY aa.Activity_ID) as rn
	,aa.BR_CM_VENDOR_Val
FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa

WHERE
	 aa.Snapshot_Date = @rpLastPeriod 
AND	aa.BR_ProjectNumber IN (@rpProject)
)
SELECT a.* INTO #l2l3_d FROM a WHERE a.rn = 1

CREATE INDEX idx_#l2l3d ON #l2l3_d (Snapshot_Date, BR_L2WorkPackage)



-- Activity names changing over time results in duplicate counting
DROP TABLE IF EXISTS #Activity_Names_d
SELECT
	 a.Snapshot_Date
	,a.Activity_ID
	,a.Activity_Name
	,a.PercentComplete
INTO #ActivityNames_d
FROM (
	SELECT 
		 aa.Snapshot_Date
		,aa.Activity_ID
		,aa.Activity_Name
		,ROW_NUMBER() OVER (PARTITION BY aa.Activity_ID ORDER BY aa.Snapshot_Date) as rn
		,aa.BR_Percent_Complete as PercentComplete
	FROM NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	WHERE aa.Snapshot_Date = @rpPeriod
	  AND aa.BR_ProjectNumber IN (@rpProject)
) a 
WHERE a.rn = 1


-->> Creating the summary table into which we'll dump our data
CREATE TABLE #tt_d (
   [ProjectNumber]	VARCHAR(30)
  ,[Activity_ID]	VARCHAR(30)
  ,[PIEPCCC]		VARCHAR(10)
  ,[Window]			VARCHAR(10)
  ,[WorkWeek]		VARCHAR(10)
  ,[Hours]		DECIMAL(19,6)
  ,[HoursLTD]		DECIMAL(19,6)
  ,[Type]		VARCHAR(20)
  ,[Activity_Vendor]  VARCHAR(20)

)


/*------------------------------------------------------------------------------------------------*/
-->> PLANNED / BASELINE
/*------------------------------------------------------------------------------------------------*/
INSERT INTO #tt_d (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]

)

SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,SUM(cc.Value) AS 'Forecast_Hours'
	,0
	,cc.Type
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0206c_ActivityL2Metrics_Daily cc

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	 ON	aa.Activity_Key  = cc.Activity_Key
	AND	aa.Instance_Key  = cc.Instance_Key
	AND	aa.Snapshot_Date = @rpPeriod
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)

WHERE
	cc.Type = 'Planned'
AND	cc.Snapshot_Date = @rpPeriod

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,cc.Type
	,aa.BR_CM_VENDOR_Val


/*******************************************************/
-->> FORECAST L2
/*******************************************************/
INSERT INTO #tt_d (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]
)

SELECT
	 aa.BR_ProjectNumber AS 'ProjectNumber'
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek AS 'WorkWeek'
	,SUM(rtp.Planned_Hours) AS 'Hours'
	,0
	,'Forecast'
	,aa.BR_CM_VENDOR_Val
FROM NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	 ON	aa.Activity_Key  = rtp.Activity_Key
	AND aa.Instance_Key  = rtp.Instance_Key
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek
	,aa.BR_CM_VENDOR_Val


/* ******************************************************************************************** */
-->> FORECAST LEVEL 3 (LAST WEEK)
/* ******************************************************************************************** */
INSERT INTO #tt_d (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]
)

SELECT
	 aa.BR_ProjectNumber AS 'ProjectNumber'
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data') AS 'Activity_ID'
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek AS 'WorkWeek'
	,SUM(rtp.Remaining_Hours)
	,0
	,'Forecast Last L3'
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210d_ActivityL3_Weekly aa
	 ON	aa.Activity_Key  = rtp.Activity_Key
	AND aa.Instance_Key  = rtp.Instance_Key
	AND	aa.Snapshot_Date = rtp.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.Snapshot_Date = @rpLastPeriod
	AND	aa.Activity_Type IN ('TT_Task','TT_LOE')
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


LEFT JOIN #l2l3_d l2aa
	 ON	aa.BR_L2WorkPackage = l2aa.BR_L2WorkPackage
	AND	aa.Snapshot_Date = l2aa.Snapshot_Date
	AND	l2aa.Snapshot_Date = @rpLastPeriod

WHERE
	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.Snapshot_Date = @rpLastPeriod
AND	rtp.BR_IsOPGSupport = 0

GROUP BY
	 aa.BR_ProjectNumber
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data')
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek
	,aa.BR_CM_VENDOR_Val

/* ******************************************************************************************** */
-->> FORECAST LEVEL 3
/* ******************************************************************************************** */
INSERT INTO #tt_d (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]
)

SELECT
	 aa.BR_ProjectNumber AS 'ProjectNumber'
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data') AS 'Activity_ID'
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek AS 'WorkWeek'
	,SUM(rtp.Planned_Hours)
	,0
	,'Forecast L3'
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200d_ActivityL3_Daily aa
	 ON	aa.Activity_Key  = rtp.Activity_Key
	AND aa.Instance_Key  = rtp.Instance_Key
	AND	aa.Snapshot_Date = rtp.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND aa.Snapshot_Date = @rpPeriod
	AND	aa.Activity_Type IN ('TT_Task','TT_LOE')
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


LEFT JOIN #l2l3_d l2aa
	 ON	aa.BR_L2WorkPackage = l2aa.BR_L2WorkPackage
	AND	aa.Snapshot_Date = l2aa.Snapshot_Date

WHERE 
	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_IsOPGSupport = 0

GROUP BY
	 aa.BR_ProjectNumber
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data')
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek
	,aa.BR_CM_VENDOR_Val

    


/* ******************************************************************************************** */
-->> EARNED
/* ******************************************************************************************** */
INSERT INTO #tt_d
SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,SUM(cc.Value) AS 'Hours'
	,0 AS 'HoursLTD'
	,'Earned'
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0206c_ActivityL2Metrics_Daily cc

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	 ON	aa.Instance_Key = cc.Instance_Key
	AND	aa.Activity_Key = cc.Activity_Key
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.Snapshot_Date = @rpPeriod
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


WHERE
	cc.Type = 'Earned'  
AND	cc.Snapshot_Date = @Live

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,aa.BR_CM_VENDOR_Val


INSERT INTO #tt_d
SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,SUM(cc.Value)
	,0
	,'Earned'
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0216c_ActivityL2Metrics_Weekly cc

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	 ON	aa.Instance_Key  = cc.Instance_Key
	AND	aa.Activity_Key  = cc.Activity_Key
	AND aa.Snapshot_Date = cc.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


WHERE cc.Type = 'Earned'	

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,aa.BR_CM_VENDOR_Val

		

INSERT INTO #tt_d
SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,0 AS 'Hours'
	,SUM(cc.Value) AS 'HoursLTD'
	,'Earned'
	,aa.BR_CM_VENDOR_Val
FROM NPDW_Report.sabi.v_fact_0206c_ActivityL2Metrics_Daily cc

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	 ON	aa.Instance_Key = cc.Instance_Key
	AND	aa.Activity_Key = cc.Activity_Key
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.Snapshot_Date = @rpPeriod
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


WHERE
	cc.Type = 'Earned LTD'
AND	cc.Snapshot_Date = @rpPeriod

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,aa.BR_CM_VENDOR_Val


/* ******************************************************************************************** */
-->> OUTPUT FROM MASTER TABLE
/* ******************************************************************************************** */

IF @rpFilter <> 'None'
BEGIN
	DELETE FROM #tt_d WHERE Activity_ID NOT IN (@rpActivity)
END

SELECT
	PercentComplete,
	 'Group 1' = CHOOSE(@rpLevel1,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')
		
		
	)
	,'Group 2' = CHOOSE(@rpLevel2,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,'Group 3' = CHOOSE(@rpLevel3,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,'Group 4' = CHOOSE(@rpLevel4,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,'Group 5' = CHOOSE(@rpLevel5,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_PV]
	,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC]
	,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_EV]
	,SUM(CASE WHEN [Type] = 'Forecast Last L3' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC3]  
	,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_PV]
	,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC]
	,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] = @rpPeriodWeek THEN [HoursLTD] ELSE 0 END) AS [LTD_EV]
	--  ,SUM(CASE WHEN [Type] = 'Forecast L3' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC3]
	,SUM(CASE WHEN [Type] = 'Planned'  THEN [Hours] ELSE 0 END) AS [LC_PV]
	,SUM(CASE WHEN [Type] = 'Forecast' THEN [Hours] ELSE 0 END) AS [LC_FC]
	,SUM(CASE WHEN [Type] = 'Earned'   THEN [Hours] ELSE 0 END) AS [LC_EV] 
	,SUM(CASE WHEN [Type] = 'Forecast L3' THEN [Hours] ELSE 0 END) AS [LC_FC3]

INTO #final_d
FROM #tt_d t

LEFT JOIN #e e
	ON t.ProjectNumber = e.project_number
	
LEFT JOIN #vd vd
	ON t.Activity_ID = vd.Activity_ID

	LEFT JOIN #rd rd
	ON t.Activity_ID = rd.Activity_ID

LEFT JOIN #ActivityNames_d a
	ON t.Activity_ID = a.Activity_ID
	
LEFT JOIN (
	SELECT  '1' AS 'ID',  'Project Management' AS 'Title' UNION
	SELECT  '2',  'Inspections' UNION
	SELECT  '3',  'Engineering' UNION
	SELECT  '4',  'Procurement' UNION
	SELECT  '5',  'Construction' UNION
	SELECT  '6',  'Commissioning' UNION
	SELECT  '9',  'Closeout' UNION
	SELECT  'ZZ', 'Not Defined' UNION
	SELECT  'Z',  'New Activities' UNION
	SELECT  'O',  'Others'
) p

ON t.PIEPCCC = p.ID

LEFT JOIN (
	SELECT DISTINCT 
		 ew.ExecWindowCode
		,ew.ExecutionWindowName 
	FROM [NPDW].[dbo].[v_dim_ExecutionWindow] ew
) ew

ON t.Window = ew.ExecWindowCode

GROUP BY
	 CHOOSE(@rpLevel1,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,CHOOSE(@rpLevel2,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,CHOOSE(@rpLevel3,
		'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,CHOOSE(@rpLevel4,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,CHOOSE(@rpLevel5,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	),
	PercentComplete


	SELECT 
		 --ROW_NUMBER() OVER (PARTITION BY f.[Group 3] ORDER BY f.[Group 4]) AS 'rn'
		 DENSE_RANK() OVER (PARTITION BY f.[Group 3] ORDER BY f.[Group 4]) AS 'rn' -- Used to get the unique 'Group 4' record count for Top N filter
		,f.*
	FROM #final_d f
END
ELSE
-----------------------------------------------------------------------------------------Eric's original code
BEGIN

DROP TABLE IF EXISTS #final
DROP TABLE IF EXISTS #L2LOE
DROP TABLE IF EXISTS #l2l3
DROP TABLE IF EXISTS #pb
DROP TABLE IF EXISTS #cl
DROP TABLE IF EXISTS #aa
DROP TABLE IF EXISTS #dd
DROP TABLE IF EXISTS #v		-- Earned
DROP TABLE IF EXISTS #tt	-- MASTER TABLE | Planned | Forecast | Earned 


-->> There is a possibility that multiple work packages will have the same BR_L2WorkPackage coding. To ensure that level 3 activities are not duplicated when matching we use this logic to identify only a single work package for each BR_L2WorkPackage
; WITH a as
(
SELECT 
	 aa.Snapshot_Date
	,aa.BR_L2WorkPackage
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,aa.Activity_Name
	,aa.Activity_ID + ' - ' + aa.Activity_Name AS 'WorkPackage'
	,ROW_NUMBER() OVER (PARTITION BY aa.Snapshot_Date, aa.BR_L2WorkPackage ORDER BY aa.Activity_ID) as rn
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
WHERE
	( aa.Snapshot_Date = @rpPeriod OR aa.Snapshot_Date = @rpLastPeriod )
AND	aa.BR_ProjectNumber IN (@rpProject)
)


SELECT a.* INTO #l2l3 FROM a WHERE a.rn = 1

CREATE INDEX idx_#l2l3 ON #l2l3 (Snapshot_Date, BR_L2WorkPackage)


-- Activity names changing over time results in duplicate counting
DROP TABLE IF EXISTS #ActivityNames
SELECT
	 a.Snapshot_Date
	,a.Activity_ID
	,a.Activity_Name
	,a.PercentComplete
INTO #ActivityNames
FROM (
	SELECT 
		 aa.Snapshot_Date
		,aa.Activity_ID
		,aa.Activity_Name
		,ROW_NUMBER() OVER (PARTITION BY aa.Activity_ID ORDER BY aa.Snapshot_Date) as rn
		,aa.BR_Percent_Complete as PercentComplete
	FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	WHERE aa.Snapshot_Date = @rpPeriod
	  AND aa.BR_ProjectNumber IN (@rpProject)
) a 
WHERE a.rn = 1



-->> Creating the summary table into which we'll dump our data
CREATE TABLE #tt (
   [ProjectNumber]	VARCHAR(30)
  ,[Activity_ID]	VARCHAR(30)
  ,[PIEPCCC]		VARCHAR(10)
  ,[Window]			VARCHAR(10)
  ,[WorkWeek]		VARCHAR(10)
  ,[Hours]		DECIMAL(19,6)
  ,[HoursLTD]		DECIMAL(19,6)
  ,[Type]		VARCHAR(20)
  ,[Activity_Vendor] VARCHAR(50)

)



/*------------------------------------------------------------------------------------------------*/
-->> PLANNED / BASELINE
/*------------------------------------------------------------------------------------------------*/
INSERT INTO #tt (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]

)

SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,SUM(cc.Value) AS 'Forecast_Hours'
	,0
	,cc.Type
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0216c_ActivityL2Metrics_Weekly cc

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	 ON	aa.Activity_Key  = cc.Activity_Key
	AND	aa.Instance_Key  = cc.Instance_Key
	AND	aa.Snapshot_Date = cc.Snapshot_Date
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


WHERE
	cc.Type IN ('Planned')	  
AND	cc.Snapshot_Date = @rpPeriod

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,cc.Type
	,aa.BR_CM_VENDOR_Val



/*******************************************************/
-->> FORECAST L2
/*******************************************************/
INSERT INTO #tt (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]

)

SELECT
	 aa.BR_ProjectNumber AS 'ProjectNumber'
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek AS 'WorkWeek'
	,SUM(rtp.Planned_Hours) AS 'Hours'
	,0
	,'Forecast'
	,aa.BR_CM_VENDOR_Val


FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	 ON	aa.Activity_Key  = rtp.Activity_Key
	AND aa.Instance_Key  = rtp.Instance_Key
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek
	,aa.BR_CM_VENDOR_Val





/* ******************************************************************************************** */
-->> FORECAST LEVEL 3 (LAST WEEK)
/* ******************************************************************************************** */
INSERT INTO #tt (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]

)

SELECT
	 aa.BR_ProjectNumber AS 'ProjectNumber'
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data') AS 'Activity_ID'
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek AS 'WorkWeek'
	,SUM(rtp.Remaining_Hours)
	,0
	,'Forecast Last L3'
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210d_ActivityL3_Weekly aa
	 ON	aa.Activity_Key  = rtp.Activity_Key
	AND aa.Instance_Key  = rtp.Instance_Key
	AND	aa.Snapshot_Date = rtp.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.Snapshot_Date = @rpLastPeriod
	AND	aa.Activity_Type IN ('TT_Task','TT_LOE')
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


LEFT JOIN #l2l3 l2aa
	 ON	aa.BR_L2WorkPackage = l2aa.BR_L2WorkPackage
	AND	aa.Snapshot_Date = l2aa.Snapshot_Date
	AND	l2aa.Snapshot_Date = @rpLastPeriod

WHERE
	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.Snapshot_Date = @rpLastPeriod
AND	rtp.BR_IsOPGSupport = 0

GROUP BY
	 aa.BR_ProjectNumber
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data')
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek
	,aa.BR_CM_VENDOR_Val

/* ******************************************************************************************** */
-->> FORECAST LEVEL 3
/* ******************************************************************************************** */
INSERT INTO #tt (
	 [ProjectNumber]
	,[Activity_ID]
	,[PIEPCCC]
	,[Window]
	,[WorkWeek]
	,[Hours]
	,[HoursLTD]
	,[Type]
	,[Activity_Vendor]

)

SELECT
	 aa.BR_ProjectNumber AS 'ProjectNumber'
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data') AS 'Activity_ID'
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,rtp.BR_WorkWeek AS 'WorkWeek'
	,SUM(rtp.Planned_Hours)
	,0
	,'Forecast L3'
	,aa.BR_CM_VENDOR_Val

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210d_ActivityL3_Weekly aa
	 ON aa.Activity_Key  = rtp.Activity_Key
	AND aa.Instance_Key  = rtp.Instance_Key
	AND	aa.Snapshot_Date = rtp.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	aa.Snapshot_Date = @rpPeriod
	AND	aa.Activity_Type IN ('TT_Task','TT_LOE')
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


LEFT JOIN #l2l3 l2aa
	 ON	aa.BR_L2WorkPackage = l2aa.BR_L2WorkPackage
	AND	aa.Snapshot_Date = l2aa.Snapshot_Date
	AND	l2aa.Snapshot_Date = @rpPeriod

WHERE
	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_IsOPGSupport = 0

GROUP BY
	 aa.BR_ProjectNumber
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,ISNULL(l2aa.Activity_ID, aa.BR_ProjectNumber + aa.BR_PIEPCCC + '#### -Missing L2 WP Data')
	,rtp.BR_WorkWeek
	,aa.BR_CM_VENDOR_Val




/* ******************************************************************************************** */
-->> EARNED
/* ******************************************************************************************** */
INSERT INTO #tt
SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,0
	,SUM(cc.Value) AS 'HoursLTD'
	,'Earned'
	,aa.BR_CM_VENDOR_Val


FROM NPDW_Report.sabi.v_fact_0216c_ActivityL2Metrics_Weekly cc

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	 ON	aa.Instance_Key  = cc.Instance_Key
	AND	aa.Activity_Key  = cc.Activity_Key
	AND aa.Snapshot_Date = cc.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


WHERE cc.Type = 'Earned LTD'	

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.Type
	,cc.WorkWeek
	,aa.BR_CM_VENDOR_Val

INSERT INTO #tt
SELECT
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,SUM(cc.Value)
	,0
	,'Earned'
	,aa.BR_CM_VENDOR_Val


FROM NPDW_Report.sabi.v_fact_0216c_ActivityL2Metrics_Weekly cc

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	 ON	aa.Instance_Key  = cc.Instance_Key
	AND	aa.Activity_Key  = cc.Activity_Key
	AND aa.Snapshot_Date = cc.Snapshot_Date
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND CASE WHEN 'ALL' IN (@rpActivityVendor)  THEN 'ALL' ELSE aa.BR_CM_VENDOR_Val  END IN (@rpActivityVendor)


WHERE cc.Type = 'Earned'	

GROUP BY
	 aa.BR_ProjectNumber
	,aa.Activity_ID
	,aa.BR_PIEPCCC
	,aa.BR_NR_EXECUTION_WINDOWS_Val
	,cc.WorkWeek
	,aa.BR_CM_VENDOR_Val




/* ******************************************************************************************** */
-->> OUTPUT FROM MASTER TABLE
/* ******************************************************************************************** */

IF @rpFilter <> 'None'
BEGIN
	DELETE FROM #tt WHERE Activity_ID NOT IN (@rpActivity)
END

SELECT
	  a.PercentComplete,
	 'Group 1' = CHOOSE(@rpLevel1,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')
	)
	,'Group 2' = CHOOSE(@rpLevel2,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')


	)
	,'Group 3' = CHOOSE(@rpLevel3,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,'Group 4' = CHOOSE(@rpLevel4,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,'Group 5' = CHOOSE(@rpLevel5,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_PV]
	,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC]
	,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_EV]
	,SUM(CASE WHEN [Type] = 'Forecast Last L3' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC3]  
	,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_PV]
	,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC]
	,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] = @rpPeriodWeek THEN [HoursLTD] ELSE 0 END) AS [LTD_EV]
	--  ,SUM(CASE WHEN [Type] = 'Forecast L3' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC3]
	,SUM(CASE WHEN [Type] = 'Planned'  THEN [Hours] ELSE 0 END) AS [LC_PV]
	,SUM(CASE WHEN [Type] = 'Forecast' THEN [Hours] ELSE 0 END) AS [LC_FC]
	,SUM(CASE WHEN [Type] = 'Earned'   THEN [Hours] ELSE 0 END) AS [LC_EV] 
	,SUM(CASE WHEN [Type] = 'Forecast L3' THEN [Hours] ELSE 0 END) AS [LC_FC3]

INTO #final
FROM #tt t

LEFT JOIN #e e
	ON t.ProjectNumber = e.project_number

LEFT JOIN #vd vd
	ON t.Activity_ID = vd.Activity_ID

LEFT JOIN #rd rd
	ON t.Activity_ID = rd.Activity_ID

LEFT JOIN #ActivityNames a
	ON t.Activity_ID = a.Activity_ID
	
LEFT JOIN (
	SELECT  '1' AS 'ID',  'Project Management' AS 'Title' UNION
	SELECT  '2',  'Inspections' UNION
	SELECT  '3',  'Engineering' UNION
	SELECT  '4',  'Procurement' UNION
	SELECT  '5',  'Construction' UNION
	SELECT  '6',  'Commissioning' UNION
	SELECT  '9',  'Closeout' UNION
	SELECT  'ZZ', 'Not Defined' UNION
	SELECT  'Z',  'New Activities' UNION
	SELECT  'O',  'Others'
) p

ON t.PIEPCCC = p.ID

LEFT JOIN (
	SELECT DISTINCT 
		 ew.ExecWindowCode
		,ew.ExecutionWindowName 
	FROM [NPDW].[dbo].[v_dim_ExecutionWindow] ew
) ew

ON t.Window = ew.ExecWindowCode


GROUP BY
	 CHOOSE(@rpLevel1,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')

	)
	,CHOOSE(@rpLevel2,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')
	)
	,CHOOSE(@rpLevel3,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')
	)
	,CHOOSE(@rpLevel4,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')
	)
	,CHOOSE(@rpLevel5,
		 'NA'
		,e.Program
		,e.Bundle
		,e.Vendor
		,e.Unit
		,e.Project
		,t.PIEPCCC + ' - ' + p.Title
		,ISNULL(ew.ExecWindowCode, 'N/A') + ' - ' + ISNULL(ew.ExecutionWindowName, 'N/A')
		,COALESCE(t.Activity_ID, vd.Activity_ID) + ' - ' + ISNULL(a.Activity_Name, 'N/A')
		,ISNULL(vd.Sub_Project, 'N/A')
		,ISNULL(vd.descr_cpiep3c, 'N/A')
		,ISNULL(vd.Area_Manager, 'N/A')
		,ISNULL(vd.Area, 'N/A')
		,ISNULL(e.project_owner, 'N/A')
		,ISNULL(e.director, 'N/A')
		,ISNULL(e.department_manager, 'N/A')
		,ISNULL(e.project_manager, 'N/A')
		,ISNULL(e.section_manager, 'N/A')
		,ISNULL(e.csa, 'N/A')
		,ISNULL(t.Activity_Vendor, 'N/A')
		,IIF(rd.CriticalPath = 'Critical Path','Critical Path','Non-Critical Path')
	),
			 a.PercentComplete


	
	
	
	
	
	
	SELECT
    f.[Group 1],
    f.[Group 2],
    f.[Group 3],
    f.[Group 4],
    f.[Group 5],
    SUM(f.[Week_PV]) AS Week_PV,
    SUM(f.[Week_FC]) AS Week_FC,
    SUM(f.[Week_EV]) AS Week_EV,
    SUM(f.[Week_FC3]) AS Week_FC3,
    SUM(f.[LTD_PV]) AS LTD_PV,
    SUM(f.[LTD_FC]) AS LTD_FC,
    SUM(f.[LTD_EV]) AS LTD_EV,
    SUM(f.[LC_PV]) AS LC_PV,
    SUM(f.[LC_FC]) AS LC_FC,
    SUM(f.[LC_EV]) AS LC_EV,
    SUM(f.[LC_FC3]) AS LC_FC3,
	f.PercentComplete
INTO #tempFinal
FROM #final f

GROUP BY
    f.[Group 1],
    f.[Group 2],
    f.[Group 3],
    f.[Group 4],
    f.[Group 5],
	f.PercentComplete



	
	SELECT
		 DENSE_RANK() OVER (PARTITION BY f.[Group 3] ORDER BY f.[Group 4]) AS 'rn' -- Used to get the unique 'Group 4' record count for Top N filter
		,f.*
	FROM #tempfinal f
END

-- END ABOVE