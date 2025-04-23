
SET NOCOUNT ON;

-- Uncomment to pass values to parameters for sample output

DECLARE @rpPeriod		AS DATE		= ?
DECLARE @rpPeriodLast   	AS DATE		= DATEADD(m, -1, @rpPeriod)
DECLARE @rpProject		AS VARCHAR(5)	= ?
DECLARE @rpPhase  		AS VARCHAR(50)	= 'ALL'		--'3EXE'|'ALL' has code to include all Phases
DECLARE @rpVendor  		AS VARCHAR(50)	= 'ALL'		--'PMV'|'ALL' has code to include all Vendors
DECLARE @rpPIEPCCC 		AS VARCHAR(5)	= 'ALL'		-- 3=Engineering | ALL=All PIEPCCC
DECLARE @rpOptions		AS VARCHAR(10)	= 'x'		-- Dummy Value Needed to include all Cost.
--@rpOption: 'INT' Excludes Interest. 'CGY' Excludes Contingency. 
--@rpOption: 'ShowPIEPCCC' shows PIEPCCC in Report. 'ShowWP' shows Work Packages and PIEPCCC in Report.


-- Leave
DECLARE @rpYearStart	AS DATE		= CAST(CAST(DATEPART(year, @rpPeriod) AS VARCHAR(4)) + '-01-01' AS DATE)
DECLARE @rpYearEnd	AS DATE		= CAST(CAST(DATEPART(year, @rpPeriod) AS VARCHAR(4)) + '-12-01' AS DATE)
DECLARE @rpPeriodEAC	AS DATE		= '2018-01-01'

---------------------------------------------------------------------------------
-- Final output adding on all the extra fields.
SELECT 
   WBS.ProgramName
  ,WBS.BundleName
  ,WBS.SubBundleName
  ,WBS.ProjectNumber
  ,WBS.ProjectName
  ,WBS.PhaseName AS Phase
  ,WBS.BCSGroupName
  ,WBS.PIEPCCCName
  ,WBS.WorkPackage
  ,WBS.WorkPackageName
  ,WBS.WP_VendorName
  ,WBS.ProjectManagerName
  ,WBS.GoverningBodyName
  ,ISNULL(AS7.[FACILITY],'N/A') AS AS7_Facility
-- Month-To-Date (MTD or Current Period) | Sum of the Current Month or Period
  ,MTD_OB
  ,MTD_CB
  ,MTD_TB
  ,MTD_AC

-- Year-To-Date (YTD) Period | 
  ,YE_OB
  ,YE_CB
  ,YE_TB
  ,YE_FC
  ,YTD_OB
  ,YTD_CB
  ,YTD_TB
  ,YTD_AC

-- Life-To-Date (LTD) Period | Sum from the begining of Time up to and including the Current Month
  ,LTD_OB
  ,LTD_CB
  ,LTD_TB
  ,LTD_AC

-- At Completion or Life Cycle (LC) | Sum of everything that matches the type. From the beginning or time to the end of time. 'All'
  ,LC_CB
  ,LC_TB
  ,LC_AC
  ,LC_OB
  ,LC_FC
  ,LC_RE
  ,LC_FC_Last
  ,CASE WHEN WBS.IsReleased = 1 THEN LC_FC ELSE 0 END AS LC_Rlsed_FC
  ,CASE WHEN WBS.IsReleased = 1 THEN LC_CB ELSE 0 END  AS LC_Rlsed_CB
  ,CASE WHEN WBS.IsReleased = 1 THEN LC_TB ELSE 0 END  AS LC_Rlsed_TB
-- CPI Calculation Fields
  ,LTD_CB_EVM
  ,LTD_AC_EVM
  ,LTD_EV_EVM
  ,LTD_CB_LOE
  ,LTD_AC_LOE
  ,LTD_EV_LOE



FROM [eic].[v_fact_0326a_WP_CostMetrics_Monthly] t

INNER JOIN [eic].[v_dim_0352b_WBS_Reporting] WBS
   ON WBS.ID = t.ID
  AND WBS.SNAPSHOT_DATE = t.SNAPSHOT_DATE

LEFT JOIN [NPDW_Report].[dbo].[ORSUSR_TIDPJMST] AS7
     ON WBS.ProjectNumber = RIGHT([PROJECT_NBR],5)

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
  AND WBS.WP_Type_Summary NOT IN(@rpOptions)
  AND WBS.SNAPSHOT_DATE	IN (@rpPeriod)--,@rpPeriodLast)--,@rpPeriodEAC)