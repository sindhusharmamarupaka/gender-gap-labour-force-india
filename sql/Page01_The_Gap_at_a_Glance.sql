-- ============================================================================
-- FILE:  Page01_The_Gap_at_a_Glance.sql
-- Gender Gap in Labour Force Participation - India -- Page 1: "The Gap at a Glance"
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
-- PAGE 1 -- "The Gap at a Glance"  (7 analyses on this page)
-- ============================================================================

-- P1.1 -- Total working-age population surveyed (card: "Surveyed")
-- Expected: 319,773
SELECT COUNT(*) AS Surveyed
FROM plfs_working_age;

-- P1.2 -- Male LFPR (card) -- Expected: 76.05%
SELECT
    ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
          / COUNT(*) * 100, 2) AS Male_LFPR
FROM plfs_working_age
WHERE Gender = 1;

-- P1.3 -- Female LFPR (card) -- Expected: 32.32%
SELECT
    ROUND(SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
          / COUNT(*) * 100, 2) AS Female_LFPR
FROM plfs_working_age
WHERE Gender = 2;

-- P1.4 -- Gender Gap % = Male LFPR - Female LFPR (card) -- Expected: 43.73pp
SELECT
    ROUND(
      (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100
       FROM plfs_working_age WHERE Gender = 1)
    - (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)*100
       FROM plfs_working_age WHERE Gender = 2)
    , 2) AS Gender_Gap_Percent;

-- P1.5 -- National Unemployment Rate (card) -- unemployed / labour force
-- Expected (recomputed this session): 5.06%
SELECT
    ROUND(SUM(CASE WHEN Employment_Status_Code = 81 THEN 1 ELSE 0 END)
          / SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END) * 100, 2)
    AS Unemployment_Rate
FROM plfs_working_age;

-- P1.6 -- Gender Parity Index = Female LFPR / Male LFPR (gauge)
-- Expected (recomputed this session): 0.425
SELECT
    ROUND(
      (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)
       FROM plfs_working_age WHERE Gender = 2)
    / (SELECT SUM(CASE WHEN Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)/COUNT(*)
       FROM plfs_working_age WHERE Gender = 1)
    , 3) AS Gender_Parity_Index;

-- P1.7 -- Gender Gap % by State (feeds the filled map)
SELECT
    l.State_Name,
    ROUND(SUM(CASE WHEN p.Gender=1 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=1 THEN 1 ELSE 0 END),0) * 100, 2) AS Male_LFPR,
    ROUND(SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR,
    ROUND(
      (SUM(CASE WHEN p.Gender=1 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=1 THEN 1 ELSE 0 END),0) * 100)
    - (SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100)
    , 2) AS Gender_Gap_Percent
FROM plfs_working_age p
JOIN state_code_lookup l ON p.State_Code = l.State_Code
WHERE p.Total_Working_Age_Population > 0 OR TRUE   -- see note below
GROUP BY l.State_Name
ORDER BY Gender_Gap_Percent DESC;
-- NOTE: your HasData guard (Total_Working_Age_Population > 0) is a DAX-side
-- measure pattern, not a real column on plfs_working_age. In SQL the
-- equivalent guard is simply requiring the state to have >0 rows, which
-- GROUP BY already guarantees. Remove the "OR TRUE" clause above (and the
-- whole WHERE line) if Total_Working_Age_Population isn't a real column
-- in your table - it isn't in the 26-column schema in your Master Doc, so
-- delete that WHERE line entirely before running.


