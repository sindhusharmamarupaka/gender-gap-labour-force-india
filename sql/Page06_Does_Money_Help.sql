-- ============================================================================
-- FILE:  Page06_Does_Money_Help.sql
-- Gender Gap in Labour Force Participation - India -- Page 6: "Does Money Help?"
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
-- PAGE 6 -- "Does Money Help?"  (7 analyses on this page)
-- ============================================================================
-- NOTE: These are all STATE-LEVEL analyses. FULLY CONFIRMED against your
-- actual DAX (all measures shared this session):
--
--   Avg_State_Literacy = CALCULATE(AVERAGE(Literacy_Rates[2023-24]), ALL(Literacy_Rates))
--   Avg_State_GSDP     = CALCULATE(AVERAGE(GSDP_Income[Per Capita GSDP - 2023-24]), ALL(GSDP_Income))
--   Female_LFPR_HighLiteracy =
--   CALCULATE([Female_LFPR_Raw],
--       FILTER(VALUES(State_Lookup[State_Name]),
--           CALCULATE(AVERAGE(Literacy_Rates[2023-24])) > [Avg_State_Literacy]))
--
-- Both threshold measures are exactly the plain unweighted AVERAGE() over
-- the whole state-level table that this file already uses below - no
-- change needed to the threshold logic itself.
--
-- One fix already made to how the result is computed:
--   [Female_LFPR_Raw] is RE-EVALUATED inside the filtered state context --
--   i.e. it POOLS every individual respondent across all matching states
--   into one LFPR, not an average of each state's own percentage. The
--   queries below pool at the individual level, matching this.
-- Threshold values confirmed from your actual literacy/GSDP CSVs this
-- session: Avg_State_Literacy ~82.85%, Avg_State_GSDP ~Rs 252,746.50.

-- P6.1 -- Female LFPR in High-Literacy states (states above the mean)
SELECT
    ROUND(SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_HighLiteracy
FROM plfs_working_age p
JOIN state_code_lookup l ON p.State_Code = l.State_Code
WHERE l.State_Name IN (
    SELECT lit.`State/UT`
    FROM state_rural_literacy_rates_2019_2024 lit
    WHERE lit.`2023-24` > (SELECT AVG(`2023-24`) FROM state_rural_literacy_rates_2019_2024)
);

-- P6.2 -- Female LFPR in Low-Literacy states (states at or below the mean)
SELECT
    ROUND(SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_LowLiteracy
FROM plfs_working_age p
JOIN state_code_lookup l ON p.State_Code = l.State_Code
WHERE l.State_Name IN (
    SELECT lit.`State/UT`
    FROM state_rural_literacy_rates_2019_2024 lit
    WHERE lit.`2023-24` <= (SELECT AVG(`2023-24`) FROM state_rural_literacy_rates_2019_2024)
);

-- P6.3 -- Female LFPR in High-GSDP states (states above the mean)
SELECT
    ROUND(SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_HighGSDP
FROM plfs_working_age p
JOIN state_code_lookup l ON p.State_Code = l.State_Code
WHERE l.State_Name IN (
    SELECT g.State
    FROM state_per_capita_income_gsdp_2019_2024 g
    WHERE g.`Per Capita GSDP - 2023-24` > (SELECT AVG(`Per Capita GSDP - 2023-24`) FROM state_per_capita_income_gsdp_2019_2024)
);

-- P6.4 -- Literacy vs Female LFPR correlation (Pearson r, state-level)
-- MySQL has no built-in CORR() before 8.0.2 window-fn era on some builds,
-- so this computes Pearson's r manually.
WITH state_stats AS (
    SELECT
        lit.`2023-24` AS x,
        SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100 AS y
    FROM plfs_working_age p
    JOIN state_code_lookup l ON p.State_Code = l.State_Code
    JOIN state_rural_literacy_rates_2019_2024 lit ON lit.`State/UT` = l.State_Name
    GROUP BY l.State_Name, lit.`2023-24`
)
SELECT
    ROUND(
      (COUNT(*) * SUM(x*y) - SUM(x)*SUM(y))
      / SQRT( (COUNT(*)*SUM(x*x) - SUM(x)*SUM(x)) * (COUNT(*)*SUM(y*y) - SUM(y)*SUM(y)) )
    , 3) AS Literacy_LFPR_Correlation
FROM state_stats;

-- P6.5 -- GSDP vs Female LFPR correlation (Pearson r, state-level)
WITH state_stats AS (
    SELECT
        g.`Per Capita GSDP - 2023-24` AS x,
        SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100 AS y
    FROM plfs_working_age p
    JOIN state_code_lookup l ON p.State_Code = l.State_Code
    JOIN state_per_capita_income_gsdp_2019_2024 g ON g.State = l.State_Name
    GROUP BY l.State_Name, g.`Per Capita GSDP - 2023-24`
)
SELECT
    ROUND(
      (COUNT(*) * SUM(x*y) - SUM(x)*SUM(y))
      / SQRT( (COUNT(*)*SUM(x*x) - SUM(x)*SUM(x)) * (COUNT(*)*SUM(y*y) - SUM(y)*SUM(y)) )
    , 3) AS GSDP_LFPR_Correlation
FROM state_stats;

-- P6.6 -- State-level bubble chart source data (Literacy, GSDP, Female LFPR)
SELECT
    l.State_Name,
    lit.`2023-24` AS Avg_State_Literacy,
    g.`Per Capita GSDP - 2023-24` AS GSDP_2023_24,
    ROUND(SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_Raw
FROM plfs_working_age p
JOIN state_code_lookup l ON p.State_Code = l.State_Code
JOIN state_rural_literacy_rates_2019_2024 lit ON lit.`State/UT` = l.State_Name
JOIN state_per_capita_income_gsdp_2019_2024 g ON g.State = l.State_Name
GROUP BY l.State_Name, lit.`2023-24`, g.`Per Capita GSDP - 2023-24`
ORDER BY l.State_Name;

-- P6.7 -- GSDP vs Female LFPR scatter (same pair, without literacy - second scatter on this page)
SELECT
    l.State_Name,
    g.`Per Capita GSDP - 2023-24` AS GSDP_2023_24,
    ROUND(SUM(CASE WHEN p.Gender=2 AND p.Employment_Status_Code IN (11,12,21,31,41,51,81) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN p.Gender=2 THEN 1 ELSE 0 END),0) * 100, 2) AS Female_LFPR_Raw
FROM plfs_working_age p
JOIN state_code_lookup l ON p.State_Code = l.State_Code
JOIN state_per_capita_income_gsdp_2019_2024 g ON g.State = l.State_Name
GROUP BY l.State_Name, g.`Per Capita GSDP - 2023-24`
ORDER BY l.State_Name;


