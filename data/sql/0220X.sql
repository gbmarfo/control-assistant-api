SET NOCOUNT ON; 

DECLARE @rpProject	VARCHAR(20) = ?
DECLARE @rpPeriod		DATE = ?
DECLARE @rpPIEPCCC	VARCHAR(MAX)  = ?


DROP TABLE IF EXISTS #rd
SELECT DISTINCT
	 r.OPG_WP AS 'Activity_ID'
	,r.WP_Description AS 'Activity_Name'
	,CriticalPath = IIF(r.rfr_cr_filter = 'critical','Critical Path','Non-Critical Path')
INTO #rd
FROM NPDW_Report.ebx.v_INV_TF_0069_OPG_WP_Lookup_Live r

WHERE r.OPG_WP IS NOT NULL
  AND r.project_no IN (@rpProject)



;WITH WW AS (
	SELECT DISTINCT
		 WorkMonth = CAST(LEFT(tpp.FiscalMonth, 4) + '-' + RIGHT(tpp.FiscalMonth, 2) + '-01' AS DATE)
		,WorkWeek = tpp.WorkWeek
		,SnapshotDate = MAX(tpp.Date)
	FROM [NPDW_Report].[sabi].[v_dim_0254_TimePhasePeriod] tpp 
	WHERE tpp.WorkWeek IS NOT NULL 
	GROUP BY CAST(LEFT(tpp.FiscalMonth, 4) + '-' + RIGHT(tpp.FiscalMonth, 2) + '-01' AS DATE), tpp.WorkWeek
)



SELECT
	 a.*
	,SV_WTD = ROUND(Earned_WTD - Planned_WTD, 2)
	,SV_LTD = ROUND(Earned_LTD - Planned_LTD, 2)
FROM (
	SELECT
		 ad.Snapshot_Date
		,[ProjectNumber] = aa.BR_ProjectNumber 
		,aa.Activity_ID
		,aa.Activity_Name
		,[Activity] = aa.Activity_ID + ' - '  + aa.Activity_Name
		,[CriticalPath] = COALESCE(r.CriticalPath, 'Not Assigned')
		,[Earned_WTD] = SUM(CASE WHEN ad.[Type] = 'Earned' THEN ad.[Value] ELSE 0 END)
		,[Earned_LTD] = SUM(CASE WHEN ad.[Type] = 'Earned LTD' THEN ad.[Value] ELSE 0 END)
		,[Planned_WTD] = SUM(CASE WHEN ad.[Type] = 'Planned' THEN ad.[Value] ELSE 0 END)
		,[Planned_LTD] = SUM(CASE WHEN ad.[Type] = 'Planned LTD' THEN ad.[Value] ELSE 0 END)
		,aa.Start
		,aa.Finish
		,aa.ApprBL_Start
		,aa.ApprBL_Finish
		,aa.BR_Percent_Complete
	FROM [NPDW_Report].[sabi].[v_fact_0216c_ActivityL2Metrics_Weekly] ad

	INNER JOIN [NPDW_Report].[sabi].[v_fact_0210c_ActivityL2_Weekly] aa
		 ON ad.Activity_Key = aa.Activity_Key
		AND ad.Instance_Key = aa.Instance_Key
		AND ad.Snapshot_Date = aa.Snapshot_Date

	INNER JOIN (
		SELECT DISTINCT
			 WorkMonth = CAST(LEFT(tpp.FiscalMonth, 4) + '-' + RIGHT(tpp.FiscalMonth, 2) + '-01' AS DATE)
			,WorkWeek = tpp.WorkWeek
			,SnapshotDate = MAX(tpp.Date)
		FROM [NPDW_Report].[sabi].[v_dim_0254_TimePhasePeriod] tpp 
		WHERE tpp.WorkWeek IS NOT NULL 
		GROUP BY CAST(LEFT(tpp.FiscalMonth, 4) + '-' + RIGHT(tpp.FiscalMonth, 2) + '-01' AS DATE), tpp.WorkWeek -- Comment out to change to monthly
	) ww
		 ON ad.WorkWeek = ww.WorkWeek
		AND ad.Snapshot_Date = ww.SnapshotDate

	LEFT JOIN #rd r
		ON r.Activity_ID = aa.Activity_ID

	WHERE ad.Type IN ('Earned', 'Earned LTD', 'Planned LTD', 'Planned')
	  AND aa.Snapshot_Date = @rpPeriod
	  AND aa.BR_ProjectNumber IN (@rpProject)
	  AND aa.BR_PIEPCCC IN (SELECT value FROM STRING_SPLIT(@rpPIEPCCC, ','))
  
	GROUP BY 
		 ad.Snapshot_Date
		,aa.BR_ProjectNumber 
		,aa.Activity_ID
		,aa.Activity_Name
		,aa.Activity_ID + ' - '  + aa.Activity_Name
		,COALESCE(r.CriticalPath, 'Not Assigned')
		,aa.Start
		,aa.Finish
		,aa.ApprBL_Start
		,aa.ApprBL_Finish
		,aa.BR_Percent_Complete
) a
WHERE ROUND(Earned_WTD - Planned_WTD, 0) <> 0 
   OR ROUND(Earned_LTD - Planned_LTD, 0) <> 0
ORDER BY 16 