-- ============================================================================
-- FILE:  Page04_Working_But_How.sql
-- Gender Gap in Labour Force Participation - India -- Page 4: "Working, But How?"
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
-- PAGE 4 -- "Working, But How?"  (8 analyses on this page)
-- ============================================================================

-- P4.1 -- Formal Job % overall. CONFIRMED against your actual DAX
-- (shared this session):
--
--   Formal_Job_Percent = DIVIDE(
--       CALCULATE(COUNTROWS(PLFS_Main),
--           Employment_Status_Code IN {"Regular Salaried/Wage Employee",
--               "Casual Labour (Public Works)", "Casual Labour (Other Work)"},
--           FILTER(PLFS_Main, Eligible_Paid_Leave="Yes" ||
--               Social_Security_Benefits<>"Not Eligible for Any Benefits")),
--       CALCULATE(COUNTROWS(PLFS_Main),
--           Employment_Status_Code IN {same three codes}) ) * 100
--
-- TWO IMPORTANT FIXES vs the previous version of this file:
--   1. It's OR, not AND -- "formal" means paid leave OR some social
--      security, not both required. Much more permissive than my earlier
--      AND-based version, so the number jumps a lot.
--   2. Population is the SAME restricted set as Job_Quality_Index: only
--      Regular Salaried (31) + Casual Labour Public Works (41) + Casual
--      Labour Other Work (51). Self-employed (11,12) and unpaid family
--      workers (21) are excluded, same as JQI.
-- Expected (recomputed this session with corrected logic): 37.99%
SELECT
    ROUND(SUM(CASE WHEN Eligible_Paid_Leave = 1 OR Social_Security_Benefits <> 8 THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2) AS Formal_Job_Percent
FROM plfs_working_age
WHERE Employment_Status_Code IN (31,41,51);

-- P4.2 -- Formal Job % - Female only
-- Expected (recomputed this session with corrected logic): 39.71%
SELECT
    ROUND(SUM(CASE WHEN Eligible_Paid_Leave = 1 OR Social_Security_Benefits <> 8 THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2) AS Formal_Job_Percent_Female
FROM plfs_working_age
WHERE Employment_Status_Code IN (31,41,51) AND Gender = 2;
-- NOTE: population is the same restricted formal-employment set as P4.1
-- (31,41,51), matching your confirmed DAX exactly.

-- P4.3 / P4.4 -- Job Quality Index - Female / Male. CONFIRMED against your
-- actual DAX (shared this session):
--
--   Job_Quality_Index =
--   CALCULATE(
--       AVERAGEX(
--           FILTER(PLFS_Main, PLFS_Main[Employment_Status_Code] IN {
--               "Regular Salaried/Wage Employee",
--               "Casual Labour (Public Works)",
--               "Casual Labour (Other Work)" }),
--           ( IF(Eligible_Paid_Leave="Yes",1,0)
--           + IF(Social_Security_Benefits<>"Not Eligible for Any Benefits",1,0)
--           + IF(Job_Contract_Type<>"No Written Contract",1,0) ) / 3 * 100
--       )
--   )
--
-- TWO IMPORTANT FIXES vs the previous version of this file:
--   1. Population is ONLY Regular Salaried (31) + Casual Labour Public
--      Works (41) + Casual Labour Other Work (51) -- NOT all 6 employed
--      codes. Self-employed (11,12) and unpaid family workers (21) are
--      excluded from JQI entirely, since contract type doesn't apply to them.
--   2. Job_Contract_Type code mapping was backwards in the previous version.
--      Checked against the real data this session: casual labourers (41,51)
--      are coded 1 for Job_Contract_Type in 100% of cases, which only makes
--      sense if code 1 = "No Written Contract" (casual work never has a
--      contract). So "has contract" = Job_Contract_Type IN (2,3,4), not (1,2,3).
--   3. Social_Security_Benefits <> 8 (same fix as P4.1/P4.2 above) -- code 9
--      ("Not known") counts as a YES under your DAX's <> logic.
--
-- Expected (recomputed this session with corrected logic):
--   Overall 31.17 | Female 32.43 | Male 30.76
SELECT
    Gender_Label,
    ROUND(AVG(
        (CASE WHEN Eligible_Paid_Leave = 1 THEN 1 ELSE 0 END
       + CASE WHEN Social_Security_Benefits <> 8 THEN 1 ELSE 0 END
       + CASE WHEN Job_Contract_Type <> 1 THEN 1 ELSE 0 END) / 3.0 * 100
    ), 2) AS Job_Quality_Index
FROM (
    SELECT *, CASE Gender WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' END AS Gender_Label
    FROM plfs_working_age
    WHERE Employment_Status_Code IN (31,41,51) AND Gender IN (1,2)
) t
GROUP BY Gender_Label;

-- P4.5 -- Average Wage Gap = Male avg earnings - Female avg earnings
-- (earnings > 0 only, combining regular salaried + self-employed income)
-- Expected (recomputed this session): Male avg ~19,663.81, Female avg
-- ~11,617.91, Gap ~8,045.90
SELECT
    ROUND(AVG(CASE WHEN Gender = 1 THEN total_earnings END), 2) AS Male_Avg_Wage,
    ROUND(AVG(CASE WHEN Gender = 2 THEN total_earnings END), 2) AS Female_Avg_Wage,
    ROUND(AVG(CASE WHEN Gender = 1 THEN total_earnings END)
        - AVG(CASE WHEN Gender = 2 THEN total_earnings END), 2) AS Average_Wage_Gap
FROM (
    SELECT Gender,
           COALESCE(Earnings_Regular_Salaried,0) + COALESCE(Earnings_Self_Employed,0) AS total_earnings
    FROM plfs_working_age
    WHERE Employment_Status_Code IN (11,12,21,31,41,51)
) t
WHERE total_earnings > 0;

-- P4.6 -- Formal vs Informal count by Gender (bar chart)
-- Updated to the confirmed Formal_Job_Percent DAX: OR logic (not AND),
-- and the same restricted population (31,41,51) as P4.1/P4.2.
SELECT
    CASE Gender WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' END AS Gender,
    SUM(CASE WHEN Eligible_Paid_Leave = 1 OR Social_Security_Benefits <> 8 THEN 1 ELSE 0 END) AS Formal_Count,
    SUM(CASE WHEN NOT (Eligible_Paid_Leave = 1 OR Social_Security_Benefits <> 8) THEN 1 ELSE 0 END) AS Informal_Count
FROM plfs_working_age
WHERE Employment_Status_Code IN (31,41,51) AND Gender IN (1,2)
GROUP BY Gender;

-- P4.7 -- Female/Male Avg Wage by Enterprise_Group. CONFIRMED against your
-- actual Power Query M code (shared this session):
--   Government = Government/Local Body (5), Public Sector Enterprise (6),
--                Autonomous Body (7)
--   Private    = Public/Private Limited Company (8)
--   Self-Employed = Proprietary Male/Female (1,2), Partnership Same/
--                Different Household (3,4)
--   Other      = everything else (Co-operative Society, Trust/Non-Profit,
--                Employer's Household, Others, Not Applicable/Not Known)
-- This is a different (and more accurate) grouping than the previous
-- version of this file, which mistakenly split 5 from 6/7 and put 8 with
-- the cooperative bucket instead of alone as "Private."
-- Expected (recomputed this session, earnings > 0 only):
--   Government: Male 37,807.90 | Female 25,769.10
--   Private:    Male 24,912.62 | Female 21,536.59
--   Self-Employed: Male 16,423.49 | Female 7,523.15
--   Other:      Male 15,881.78 | Female 8,504.02
SELECT
    CASE
        WHEN Enterprise_Type_Code IN (5,6,7) THEN 'Government'
        WHEN Enterprise_Type_Code = 8 THEN 'Private'
        WHEN Enterprise_Type_Code IN (1,2,3,4) THEN 'Self-Employed'
        ELSE 'Other'
    END AS Enterprise_Group,
    ROUND(AVG(CASE WHEN Gender = 1 THEN total_earnings END), 2) AS Male_Avg_Wage,
    ROUND(AVG(CASE WHEN Gender = 2 THEN total_earnings END), 2) AS Female_Avg_Wage
FROM (
    SELECT Gender, Enterprise_Type_Code,
           COALESCE(Earnings_Regular_Salaried,0) + COALESCE(Earnings_Self_Employed,0) AS total_earnings
    FROM plfs_working_age
    WHERE Employment_Status_Code IN (11,12,21,31,41,51)
) t
WHERE total_earnings > 0
GROUP BY Enterprise_Group;

-- P4.8 -- Job Quality Index by Gender (single-series version of P4.3/P4.4,
-- for the third Page 4 chart). Same confirmed logic as above.
-- Expected: Female 32.43 | Male 30.76
SELECT
    CASE Gender WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' END AS Gender,
    ROUND(AVG(
        (CASE WHEN Eligible_Paid_Leave = 1 THEN 1 ELSE 0 END
       + CASE WHEN Social_Security_Benefits <> 8 THEN 1 ELSE 0 END
       + CASE WHEN Job_Contract_Type <> 1 THEN 1 ELSE 0 END) / 3.0 * 100
    ), 2) AS Job_Quality_Index
FROM plfs_working_age
WHERE Employment_Status_Code IN (31,41,51) AND Gender IN (1,2)
GROUP BY Gender;


