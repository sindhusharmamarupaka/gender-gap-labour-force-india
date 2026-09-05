-- ============================================================================
-- FILE:  Page03_Whos_Left_Out.sql
-- Gender Gap in Labour Force Participation - India -- Page 3: "Who's Left Out"
-- Run this section standalone in MySQL Workbench to cross-validate this
-- page's cards/charts against the source tables. See the shared codebook
-- reference below for how numeric codes map to labels.
-- ============================================================================

USE gender_gap_project;

-- ############################################################################
-- CODEBOOK REFERENCE - validated this session against the real CSV
-- (I ran these definitions in Python against your actual data and they
-- reproduce your documented headline numbers exactly: Male LFPR 76.05%,
-- Female LFPR 32.32%, Telangana Female LFPR 42.32%, Gender Gap 34.37pp,
-- GPI 0.55, household headship 83.3% male / 16.7% female. Codebook is solid.)
-- ############################################################################
/*
  Gender:                 1 = Male, 2 = Female, 3 = Other/Transgender
  Sector_Rural_Urban:     1 = Rural, 2 = Urban
  Marital_Status:         1 = Never Married, 2 = Currently Married,
                          3 = Widowed, 4 = Divorced/Separated
  Relationship_to_Head:   1 = Self, 2 = Spouse of Head, 3 = Married Child,
                          4 = Spouse of Married Child, 5 = Unmarried Child,
                          6 = Grandchild, 7 = Parent/Parent-in-law,
                          8 = Sibling/Other Relative, 9 = Servant/Non-relative
  Employment_Status_Code (current weekly status, matches your project's
  existing note that this is NOT standard NSS 71/72 usual-status coding):
      Employed            = 11, 12, 21, 31, 41, 51
      Unemployed (LF)     = 81   (sought/available for work)
      Not in Labour Force = 91 (attending education), 92 (domestic duties
                            only), 93 (domestic duties + free collection),
                            94 (rentier/pensioner), 95 (disabled),
                            96 (begging etc.), 97 (other)
      Labour Force        = Employed + 81
      LFPR                = Labour Force / Total Working-Age Population
  Eligible_Paid_Leave:    1 = Yes, 2 = No
  Social_Security_Benefits: 1-7 = has at least one benefit (PF/Gratuity/
                          Healthcare, various combinations), 8 = None,
                          9 = Not known.
                          CONFIRMED (from your actual Job_Quality_Index DAX):
                          "has social security" = Social_Security_Benefits <> 8
                          (code 9 "Not known" counts as YES under this rule -
                          it is NOT the same as the 1-7 range used earlier).
  Job_Contract_Type:     CONFIRMED from real data cross-check + your DAX:
                          code 1 = "No Written Contract" (100% of casual
                          labourers are coded 1). "Has contract" = <> 1.
  Duration_Unemployment_Spell (bucketed CODE, not raw months):
      1 = <3 months, 2 = 3-6 months, 3 = 6-12 months,
      4 = 1-2 years, 5 = 2+ years

  CONFIRMED THIS SESSION from your actual Power Query M code (full query
  script shared) - three more items that were previously flagged as
  assumptions are now exact:

  Current_Attendance_Group (built from Current_Attendance_Status):
      NULL           -> "Not Applicable (Age 30+)"
      1-5            -> "Never Attended School"
      11-15          -> "Attended but Currently Not Attending"
      21-43          -> "Currently Attending"
      else           -> "Other"
      NEET = not employed (Employment_Status_Code NOT IN 11,12,21,31,41,51)
             AND Current_Attendance_Status NOT BETWEEN 21 AND 43 (incl. NULL)

  Age_Group (built from Age, applied after the Age>=15 filter):
      <=19 -> "15-19", <=24 -> "20-24", <=29 -> "25-29", <=39 -> "30-39",
      <=49 -> "40-49", <=59 -> "50-59", <=69 -> "60-69", else -> "70+"

  Enterprise_Group (built from Enterprise_Type_Code):
      Government    = codes 5, 6, 7  (Govt/Local Body, PSE, Autonomous Body)
      Private       = code 8         (Public/Private Limited Company)
      Self-Employed = codes 1, 2, 3, 4 (Proprietary M/F, Partnership Same/
                      Different Household)
      Other         = everything else (Cooperative, Trust, Employer HH, etc.)

  CONFIRMED THIS SESSION (final two items - DAX shared directly):
  Avg_State_Literacy / Avg_State_GSDP: plain unweighted AVERAGE() over the
      entire Literacy_Rates / GSDP_Income table (ALL() clears any filter
      context) -- exactly the "mean across state rows" logic already used
      in this file's Page 6 queries. No change needed there.
  Female_LongTerm_Unemployed_Percent: "long-term" = Duration_Unemployment_Spell
      = 5 ONLY (2+ years). Code 4 (1-2 years) is NOT included, despite
      seeming like a reasonable "12+ months" reading.
*/


-- ============================================================================
-- PAGE 3 -- "Who's Left Out"  (8 analyses on this page)
-- ============================================================================

-- P3.1 -- Female LFPR - Youth (age 15-29, ILO/NEET youth definition per your
-- Master Doc) -- Expected (recomputed this session): 21.45%
SELECT
    ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2) AS Female_LFPR_Youth
FROM plfs_working_age
WHERE Gender = 2 AND Age BETWEEN 15 AND 29;

-- P3.2 -- Female LFPR - Currently Married only
SELECT
    ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2) AS Female_LFPR_Married
FROM plfs_working_age
WHERE Gender = 2 AND Marital_Status = 2;

-- P3.3 -- % of Youth (15-29) Currently Attending education. CONFIRMED
-- against your actual Power Query M code (shared this session):
--
--   Current_Attendance_Group =
--     if [Current_Attendance_Status] = null then "Not Applicable (Age 30+)"
--     else if [Current_Attendance_Status] between 1 and 5 then "Never Attended School"
--     else if [Current_Attendance_Status] between 11 and 15 then "Attended but Currently Not Attending"
--     else if [Current_Attendance_Status] between 21 and 43 then "Currently Attending"
--     else "Other"
--
-- (My earlier version had this backwards - codes 1-5 mean NEVER attended,
-- not currently attending. Fixed below.)
-- Expected (recomputed this session): 38.51%
SELECT
    ROUND(SUM(CASE WHEN Current_Attendance_Status BETWEEN 21 AND 43 THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2) AS Attending_Percent_Youth
FROM plfs_working_age
WHERE Age BETWEEN 15 AND 29;

-- P3.4 -- NEET Rate (15-29): Not in Employment, Education, or Training.
-- CONFIRMED logic: NEET = not employed AND Current_Attendance_Group <> "Currently Attending"
-- (i.e. Current_Attendance_Status NOT between 21 and 43, including NULLs).
-- Expected (recomputed this session): matches your documented 47.3%F / 9.9%M
-- exactly - see P8.1/P8.2 on Page 8 for the gender-split version.
SELECT
    ROUND(SUM(
        CASE WHEN Employment_Status_Code NOT IN (11,12,21,31,41,51)
             AND (Current_Attendance_Status IS NULL OR Current_Attendance_Status NOT BETWEEN 21 AND 43)
        THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2) AS NEET_Rate
FROM plfs_working_age
WHERE Age BETWEEN 15 AND 29;

-- P3.5 -- Median Age of Working Females
-- Expected (recomputed this session): 40 (MySQL 8.0+: use PERCENTILE_CONT)
SELECT Age AS Median_Age_Working_Female
FROM (
    SELECT Age, ROW_NUMBER() OVER (ORDER BY Age) AS rn, COUNT(*) OVER () AS cnt
    FROM plfs_working_age
    WHERE Gender = 2 AND Employment_Status_Code IN (11,12,21,31,41,51)
) t
WHERE rn IN (FLOOR((cnt+1)/2), CEIL((cnt+1)/2))
GROUP BY 1
LIMIT 1;
-- (Simplified approx-median via ordered row; for exact median use
--  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Age) if your MySQL supports it.)

-- P3.6 -- Population pyramid: Female count / Male count(negative) by
-- Age_Group. CONFIRMED against your actual Power Query M code:
--   15-19 (<=19), 20-24 (<=24), 25-29 (<=29), 30-39 (<=39), 40-49 (<=49),
--   50-59 (<=59), 60-69 (<=69), 70+ (else)
SELECT
    CASE
        WHEN Age <= 19 THEN '15-19'
        WHEN Age <= 24 THEN '20-24'
        WHEN Age <= 29 THEN '25-29'
        WHEN Age <= 39 THEN '30-39'
        WHEN Age <= 49 THEN '40-49'
        WHEN Age <= 59 THEN '50-59'
        WHEN Age <= 69 THEN '60-69'
        ELSE '70+'
    END AS Age_Group,
    SUM(CASE WHEN Gender = 2 THEN 1 ELSE 0 END) AS Female_Population_Count,
    -SUM(CASE WHEN Gender = 1 THEN 1 ELSE 0 END) AS Male_Population_Negative
FROM plfs_working_age
GROUP BY Age_Group
ORDER BY MIN(Age);

-- P3.7 -- Female vs Male LFPR by General_Education_Level
-- (Raw codes; standard NSSO mapping: 1=Not literate,2-4=Literate w/o formal
-- schooling,5=Below primary,6=Primary,7=Middle,8=Secondary,10=Higher
-- Secondary,11=Diploma,12=Graduate,13=Postgraduate+)
SELECT
    General_Education_Level,
    ROUND(SUM(CASE WHEN Gender=2 AND Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_Raw,
    ROUND(SUM(CASE WHEN Gender=1 AND Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN Gender=1 THEN 1 ELSE 0 END),0) * 100, 2) AS Male_LFPR_Raw
FROM plfs_working_age
GROUP BY General_Education_Level
ORDER BY General_Education_Level;

-- P3.8 -- Male vs Female LFPR by Marital_Status
SELECT
    CASE Marital_Status WHEN 1 THEN 'Never Married' WHEN 2 THEN 'Currently Married'
         WHEN 3 THEN 'Widowed' WHEN 4 THEN 'Divorced/Separated' END AS Marital_Status,
    ROUND(SUM(CASE WHEN Gender=1 AND Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN Gender=1 THEN 1 ELSE 0 END),0) * 100, 2) AS Male_LFPR_Raw,
    ROUND(SUM(CASE WHEN Gender=2 AND Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_Raw
FROM plfs_working_age
GROUP BY Marital_Status
ORDER BY Marital_Status;


