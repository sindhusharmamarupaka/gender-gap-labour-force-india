-- ============================================================================
-- FILE:  Page07_Your_State.sql
-- Gender Gap in Labour Force Participation - India -- Page 7: "Your State"
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
-- PAGE 7 -- "Your State"  (Telangana default, State_Code = 36)  (6 analyses)
-- ============================================================================

-- P7.1 -- Telangana Female LFPR -- Expected: 42.32%
SELECT ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100, 2)
       AS Female_LFPR
FROM plfs_working_age WHERE State_Code = 36 AND Gender = 2;

-- P7.2 -- Telangana Gender Gap % -- Expected: 34.37pp
SELECT
    ROUND(
      (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100
       FROM plfs_working_age WHERE State_Code=36 AND Gender=1)
    - (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100
       FROM plfs_working_age WHERE State_Code=36 AND Gender=2)
    , 2) AS Gender_Gap_Percent;

-- P7.3 -- Telangana Gender Parity Index -- Expected: 0.55
SELECT
    ROUND(
      (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)
       FROM plfs_working_age WHERE State_Code=36 AND Gender=2)
    / (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)
       FROM plfs_working_age WHERE State_Code=36 AND Gender=1)
    , 2) AS Gender_Parity_Index;

-- P7.4 -- Telangana Unemployment Rate -- Expected: 6.14%
SELECT
    ROUND(SUM(CASE WHEN Employment_Status_Code = 81 THEN 1 ELSE 0 END)
        / SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END) * 100, 2)
    AS Unemployment_Rate
FROM plfs_working_age WHERE State_Code = 36;

-- P7.5 -- Telangana Female LFPR vs National Female LFPR (paired bar chart)
SELECT
    (SELECT ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100,2)
     FROM plfs_working_age WHERE Gender=2) AS Female_LFPR_National,
    (SELECT ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100,2)
     FROM plfs_working_age WHERE State_Code=36 AND Gender=2) AS Female_LFPR_Raw_Telangana;

-- P7.6 -- Telangana's Rank among all 36 states/UTs by Female LFPR
WITH state_flfpr AS (
    SELECT l.State_Name, l.State_Code,
        SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100 AS Female_LFPR_Raw
    FROM plfs_working_age p
    JOIN state_code_lookup l ON p.State_Code = l.State_Code
    GROUP BY l.State_Name, l.State_Code
)
SELECT State_Name, ROUND(Female_LFPR_Raw,2) AS Female_LFPR_Raw,
       RANK() OVER (ORDER BY Female_LFPR_Raw DESC) AS State_Rank
FROM state_flfpr
HAVING State_Code = 36;


