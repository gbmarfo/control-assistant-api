
SET NOCOUNT ON;

DECLARE @rpPeriod		AS DATE		= ?
DECLARE @rpProject		AS VARCHAR(5)	= ?
DECLARE @rpPeriodLast   	AS DATE		= DATEADD(m, -1, @rpPeriod)
DECLARE @rpPhase  		AS VARCHAR(50)	= 'ALL'		--'3EXE'|'ALL' has code to include all Phases
DECLARE @rpVendor  		AS VARCHAR(50)	= 'ALL'		--'PMV'|'ALL' has code to include all Vendors
DECLARE @rpPIEPCCC 		AS VARCHAR(5)	= 'ALL'		-- 3=Engineering | ALL=All PIEPCCC
DECLARE @rpOptions		AS VARCHAR(10)	= 'x'		-- Dummy Value Needed to include all Cost.
--@rpOption: 'INT' Excludes Interest. 'CGY' Excludes Contingency. 
--@rpOption: 'ShowPIEPCCC' shows PIEPCCC in Report. 'ShowWP' shows Work Packages and PIEPCCC in Report.


---------------------------------------------------------------------------------
-- Join the Two Temp Tables #WBS and [eic].[v_fact_0326b_WP_TimePhase_Monthly] (Formerly #CostTable) to SUM and Aggregate
SELECT
	 WBS.ProgramName
	,WBS.Program
	,WBS.BundleWBS
	,WBS.BundleName
	,WBS.SubBundleName
	--,WBS.ProjectNumber
	--,WBS.ProjectName
	,COALESCE(PC.Project_Ref, WBS.ProjectNumber) AS ProjectNumber
	,COALESCE(PC.Project_Ref, WBS.ProjectNumber) + ' - ' + WBS.ProjectTitle AS ProjectName
	--,WBS.WP_Type
	,WBS.UnitGroup
	,WBS.UnitGroupSort
	--,WBS.Unit
	,WBS.UnitName
	,WBS.UnitSort
	,WBS.WP_VendorName
	,WBS.PIEPCCC
	,WBS.PIEPCCCName
	,WBS.WorkPackage
	,WBS.WorkPackageName

	-- Life-To-Date (LTD) Period | Sum from the begining of Time up to and including the Current Month
	,t.LTD_OB
	,t.LTD_CB
	,t.LTD_TB
	,t.LTD_AC

	-- At Completion or Life Cycle (LC) | Sum of everything that matches the type. From the beginning or time to the end of time. 'All'
	,t.LC_CB
	,t.LC_TB
	,t.LC_OB
	,t.LC_FC
	--,t.LC_FC_Last -- Can't Use because it uses latest period attributes.
	,l.LC_FC AS LC_FC_Last
	,t.LC_FC_SnapshotEAC

	-- CPI Calculation Fields
	,t.LTD_CB_EVM
	,t.LTD_AC_EVM
	,t.LTD_EV_EVM
	,t.LTD_CB_LOE
	,t.LTD_EV_LOE
	,t.LTD_AC_LOE
	--,t.LC_CB_LOE
	--,t.LC_FC_LOE
	--,t.LC_CB_EVM
	--,t.LC_FC_EVM

	-- CPI Calculation Fields for Last Period
	,l.LTD_CB_EVM AS LTD_CB_EVM_Last
	,l.LTD_AC_EVM AS LTD_AC_EVM_Last
	,l.LTD_EV_EVM AS LTD_EV_EVM_Last

	,l.LTD_CB_LOE AS LTD_CB_LOE_Last
	,l.LTD_AC_LOE AS LTD_AC_LOE_Last
	,l.LTD_EV_LOE AS LTD_EV_LOE_Last

FROM [eic].[v_dim_0352b_WBS_Reporting] WBS

INNER JOIN [eic].[v_fact_0326a_WP_CostMetrics_Monthly] t
--INNER JOIN [eic].[v_dim_0352b_WBS_Reporting] WBS
   ON WBS.ID = t.ID
  AND WBS.SNAPSHOT_DATE = t.SNAPSHOT_DATE

--This Code is Used to Get Last Period Values Based on Attributes from Last Period
LEFT JOIN (
	SELECT l.* 
	FROM [eic].[v_dim_0352b_WBS_Reporting] WBS
	INNER JOIN [eic].[v_fact_0326a_WP_CostMetrics_Monthly] l
	   ON l.ID = WBS.ID  
	  AND l.SNAPSHOT_DATE = WBS.SNAPSHOT_DATE
	WHERE
	      WBS.ProjectNumber	IN (@rpProject)
	  AND CASE WHEN 'ALL' IN (@rpPhase)   THEN 'ALL' ELSE WBS.Phase     END IN (@rpPhase)
	  AND CASE WHEN 'ALL' IN (@rpVendor)  THEN 'ALL' ELSE WBS.WP_Vendor END IN (@rpVendor)
	  AND CASE WHEN 'ALL' IN (@rpPIEPCCC) THEN 'ALL' ELSE WBS.PIEPCCC   END IN (@rpPIEPCCC)
	  AND WBS.WP_Type_Summary NOT IN(@rpOptions)
	  AND WBS.SNAPSHOT_DATE	= @rpPeriodLast
	) l
   ON l.ID = t.ID
  AND l.SNAPSHOT_DATE = @rpPeriodLast

  
LEFT JOIN [NPDW_Report].[cmn].[v_dim_0050_AS7_Projects] PC
   ON PC.ProjectNumber = WBS.ProjectNumber

WHERE
      WBS.ProjectNumber	IN (@rpProject)
  AND CASE WHEN 'ALL' IN (@rpPhase)   THEN 'ALL' ELSE WBS.Phase     END IN (@rpPhase)
  AND CASE WHEN 'ALL' IN (@rpVendor)  THEN 'ALL' ELSE WBS.WP_Vendor END IN (@rpVendor)
  AND CASE WHEN 'ALL' IN (@rpPIEPCCC) THEN 'ALL' ELSE WBS.PIEPCCC   END IN (@rpPIEPCCC)
  AND CASE WHEN 'CVD' IN (@rpOptions) THEN 'COVID-19' ELSE 'Ignore' END <> WBS.[COVID]
AND (
          WBS.IsReleased = 1 -- This will get all the Released work packages
OR WBS.IsReleased = CASE WHEN 'RLSD' IN (@rpOptions) THEN 1 ELSE 0 END -- If Exclude Unreleased is selected, this will evaluate to 1, so will only bring in WPs where IsReleased = 1
)
  AND WBS.WP_Type_Summary NOT IN (@rpOptions)
  AND WBS.SNAPSHOT_DATE	IN (@rpPeriod)--,@rpPeriodLast)--,@rpPeriodEAC)