SELECT *
FROM loan_data


-- SECTION 1: DATABASE OVERVIEW

SELECT
    COUNT(*) AS total_loans,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS total_defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(loan_amount_inr), 0) AS DECIMAL(12,2)) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil_score,
    ROUND(AVG(dti_ratio), 2) AS avg_dti_ratio,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2)
    AS DECIMAL(12,2)) AS total_portfolio_crore
FROM loan_data;


-- SECTION 2: DEFAULT RATE ANALYSIS

-- Default rate by CIBIL score tier
SELECT
    credit_tier,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(loan_amount_inr), 0) AS DECIMAL(12,2)) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil_score
FROM loan_data
GROUP BY credit_tier
ORDER BY default_rate_pct DESC;


-- Default rate by loan grade
SELECT
    loan_grade,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(interest_rate), 2) AS DECIMAL(5,2)) AS avg_interest_rate_pct
FROM loan_data
GROUP BY loan_grade
ORDER BY loan_grade;


-- Default rate by loan purpose (Indian context)
SELECT
    loan_purpose,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(loan_amount_inr), 0) AS DECIMAL(12,2)) AS avg_loan_inr
FROM loan_data
WHERE loan_purpose IS NOT NULL
GROUP BY loan_purpose
ORDER BY default_rate_pct DESC;


-- Default rate by employment status
SELECT
    employment_status,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(loan_amount_inr), 0) AS DECIMAL(12,2)) AS avg_loan_inr
FROM loan_data
GROUP BY employment_status
ORDER BY default_rate_pct DESC;


-- Default rate by education level
SELECT
    education,
    COUNT(*) AS loan_count,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(annual_income_inr), 2) AS DECIMAL(12,2)) AS avg_income_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil
FROM loan_data
GROUP BY education
ORDER BY default_rate_pct DESC;



-- SECTION 3: RISK SEGMENTATION

-- Risk category breakdown with financials in Crore
SELECT
    risk_category,
    COUNT(*) AS loan_count,
    CAST(ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS DECIMAL(10,2)) AS pct_of_portfolio,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
        2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(AVG(loan_amount_inr), 0) AS DECIMAL(12,2)) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil_score,
    ROUND(AVG(dti_ratio), 2) AS avg_dti,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS total_exposure_crore
FROM loan_data
GROUP BY risk_category
ORDER BY
    CASE risk_category
        WHEN 'Low Risk'       THEN 1
        WHEN 'Medium Risk'    THEN 2
        WHEN 'High Risk'      THEN 3
        WHEN 'Very High Risk' THEN 4
    END;


-- Top 50 highest-risk borrowers flagged by ML model
SELECT TOP 50
    loan_id,
    applicant_name,
    pan_number,
    credit_score AS cibil_score,
    CAST(dti_ratio  AS DECIMAL(10,2)) AS dti_ratio,
    num_late_payments,
    bankruptcies,
    ROUND(loan_amount_inr, 0) AS loan_amount_inr,
    loan_purpose,
    ROUND(ml_default_probability * 100, 1) AS default_prob_pct,
    risk_category,
    default_status
FROM loan_data
WHERE ml_risk_flag = 1
ORDER BY ml_default_probability DESC;


-- Multi-risk borrowers (3+ red flags simultaneously)
SELECT *
FROM (
    SELECT
        loan_id,
        applicant_name,
        state,
        credit_score AS cibil_score,
        CAST(dti_ratio  AS DECIMAL(10,2)) AS dti_ratio,
        num_late_payments,
        bankruptcies,
        ROUND(loan_amount_inr, 0) AS loan_amount_inr,
        ROUND(ml_default_probability * 100, 1) AS default_prob_pct,
        (CASE WHEN credit_score < 600 THEN 1 ELSE 0 END
       + CASE WHEN dti_ratio > 50 THEN 1 ELSE 0 END
       + CASE WHEN num_late_payments >= 3 THEN 1 ELSE 0 END
       + CASE WHEN bankruptcies > 0 THEN 1 ELSE 0 END
       + CASE WHEN loan_to_income_ratio > 1.0 THEN 1 ELSE 0 END) AS risk_flag_count,
        default_status,
        ml_default_probability
    FROM loan_data
) t
WHERE risk_flag_count >= 3
ORDER BY risk_flag_count DESC, ml_default_probability DESC;

SELECT * FROM loan_data



-- SECTION 4: FINANCIAL IMPACT (INR / CRORE)

-- Portfolio exposure by risk category (in Crore)
-- Assumption: 70% loss given default (LGD) — typical for unsecured loans in India
SELECT
    risk_category,
    COUNT(*) AS loan_count,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS total_exposure_crore,
    CAST(ROUND(SUM(CASE WHEN default_status = 1
              THEN loan_amount_inr END) / 10000000.0, 2) AS DECIMAL(10,2)) AS defaulted_amount_crore,
    CAST(ROUND(SUM(CASE WHEN default_status = 1
              THEN loan_amount_inr * 0.70 END) / 10000000.0, 2) AS DECIMAL(10,2)) AS estimated_loss_crore_70pct_lgd
FROM loan_data
GROUP BY risk_category
ORDER BY estimated_loss_crore_70pct_lgd DESC;


-- Interest revenue vs default loss by loan grade
SELECT
    loan_grade,
    COUNT(*) AS loan_count,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS portfolio_crore,
    CAST(ROUND(AVG(interest_rate), 2) AS DECIMAL(10,2)) AS avg_rate_pct,
    CAST(ROUND(SUM(loan_amount_inr * interest_rate / 100)
          / 10000000.0, 2) AS DECIMAL(5,2)) AS est_annual_interest_crore,
    CAST(ROUND(SUM(CASE WHEN default_status = 1
              THEN loan_amount_inr * 0.70 ELSE 0 END)
          / 10000000.0, 2) AS DECIMAL(10,2)) AS est_default_loss_crore,
    -- Net position (positive = profitable grade, negative = loss-making)
    CAST(ROUND((SUM(loan_amount_inr * interest_rate / 100)
           - SUM(CASE WHEN default_status = 1
                 THEN loan_amount_inr * 0.70 ELSE 0 END))
          / 10000000.0, 2) AS DECIMAL(10,2)) AS net_position_crore
FROM loan_data
GROUP BY loan_grade
ORDER BY loan_grade;


-- Savings if we decline loans with ML probability >= 0.70
WITH high_risk AS (
    SELECT *
    FROM loan_data
    WHERE ml_default_probability >= 0.70
)
SELECT
    COUNT(*) AS flagged_loans,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS total_exposure_crore,
    CAST(ROUND(SUM(CASE WHEN default_status = 1
              THEN loan_amount_inr * 0.70 END) / 10000000.0, 2) AS DECIMAL(10,2)) AS potential_loss_saved_crore
FROM high_risk;



-- SECTION 5: GEOGRAPHIC ANALYSIS — STATE LEVEL

-- 5a. Default rate and portfolio by state
SELECT
    state,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS total_exposure_crore,
    ROUND(AVG(credit_score), 0) AS avg_cibil_score,
    CAST(ROUND(AVG(annual_income_inr), 0) AS DECIMAL(10,2)) AS avg_income_inr
FROM loan_data
GROUP BY state
ORDER BY default_rate_pct DESC;


-- Top 10 states by total portfolio exposure
SELECT TOP 10
    state,
    COUNT(*) AS loan_count,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS exposure_crore,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct
FROM loan_data
GROUP BY state
ORDER BY exposure_crore DESC;


-- SECTION 6: TREND ANALYSIS

-- Quarterly default trend (FY format)
SELECT
    app_year,
    app_quarter,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    ROUND(AVG(loan_amount_inr), 0) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil
FROM loan_data
GROUP BY app_year, app_quarter
ORDER BY app_year, app_quarter;


-- Monthly volume and default trend
SELECT
    app_year,
    app_month,
    COUNT(*) AS loan_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS disbursed_crore
FROM loan_data
GROUP BY app_year, app_month
ORDER BY app_year, app_month;



-- SECTION 7: DEMOGRAPHIC ANALYSIS

-- Age group analysis
SELECT
    CASE
        WHEN age BETWEEN 21 AND 25 THEN '21-25'
        WHEN age BETWEEN 26 AND 30 THEN '26-30'
        WHEN age BETWEEN 31 AND 40 THEN '31-40'
        WHEN age BETWEEN 41 AND 50 THEN '41-50'
        WHEN age BETWEEN 51 AND 60 THEN '51-60'
        ELSE '60+'
    END AS age_group,
    COUNT(*) AS loan_count,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    ROUND(AVG(loan_amount_inr), 0) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil,
    CAST(ROUND(AVG(annual_income_inr), 0) AS DECIMAL(10,2)) AS avg_income_inr
FROM loan_data
GROUP BY CASE
        WHEN age BETWEEN 21 AND 25 THEN '21-25'
        WHEN age BETWEEN 26 AND 30 THEN '26-30'
        WHEN age BETWEEN 31 AND 40 THEN '31-40'
        WHEN age BETWEEN 41 AND 50 THEN '41-50'
        WHEN age BETWEEN 51 AND 60 THEN '51-60'
        ELSE '60+'
    END
ORDER BY age_group;


-- Gender analysis
SELECT
    gender,
    COUNT(*) AS loan_count,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    ROUND(AVG(loan_amount_inr), 0) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil,
    CAST(ROUND(AVG(annual_income_inr), 0) AS DECIMAL(10,2)) AS avg_income_inr
FROM loan_data
WHERE gender IN ('Male','Female')
GROUP BY gender;



-- SECTION 8: FRAUD / EARLY WARNING INDICATORS

-- 8a. Income mismatch detection (stated vs verified income)
SELECT TOP 30
    loan_id,
    applicant_name,
    pan_number,
    ROUND(annual_income_inr, 0) AS verified_income_inr,
    annual_income_stated_inr AS stated_income_inr,
    ROUND(income_discrepancy_pct, 2) AS discrepancy_pct,
    credit_score AS cibil_score,
    default_status
FROM loan_data
WHERE income_mismatch_flag = 1
ORDER BY income_discrepancy_pct DESC;


-- Aggregate fraud signal analysis
SELECT
    COUNT(*) AS suspicious_count,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    ROUND(AVG(loan_amount_inr), 0) AS avg_loan_inr
FROM loan_data
WHERE income_discrepancy_pct > 30
  AND annual_income_stated_inr > annual_income_inr;


-- EMI-to-income stress test
SELECT
    CASE
        WHEN emi_to_income_ratio < 0.30  THEN 'Comfortable (<30% of income)'
        WHEN emi_to_income_ratio < 0.50  THEN 'Manageable (30-50%)'
        WHEN emi_to_income_ratio < 0.70  THEN 'Stressed (50-70%)'
        ELSE 'Severely Stressed (>70%)'
    END AS emi_stress_bucket,
    COUNT(*) AS loan_count,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS default_rate_pct,
    ROUND(AVG(loan_amount_inr), 0) AS avg_loan_inr,
    ROUND(AVG(credit_score), 0) AS avg_cibil
FROM loan_data
GROUP BY CASE
        WHEN emi_to_income_ratio < 0.30  THEN 'Comfortable (<30% of income)'
        WHEN emi_to_income_ratio < 0.50  THEN 'Manageable (30-50%)'
        WHEN emi_to_income_ratio < 0.70  THEN 'Stressed (50-70%)'
        ELSE 'Severely Stressed (>70%)'
    END
ORDER BY default_rate_pct DESC;



-- SECTION 9: AUTOMATED LOAN DECISION ENGINE

-- Simulates real-time RBI-compliant loan decision recommendation
-- Run for any loan_id to get risk assessment

SELECT
    loan_id,
    applicant_name,
    pan_number,
    state,
    credit_score AS cibil_score,
    credit_tier,
    ROUND(dti_ratio, 2) AS dti_ratio_pct,
    num_late_payments,
    bankruptcies,
    ROUND(loan_amount_inr, 0) AS loan_amount_inr,
    loan_purpose,
    ROUND(annual_income_inr, 0) AS annual_income_inr,
    ROUND(estimated_emi, 0) AS monthly_emi_inr,
    ROUND(emi_to_income_ratio * 100, 1) AS emi_to_monthly_income_pct,
    ROUND(ml_default_probability * 100, 1) AS default_prob_pct,
    risk_category,
    CASE
        WHEN ml_default_probability >= 0.75 THEN '🔴 DECLINE — Very High Risk (RBI NPA Risk)'
        WHEN ml_default_probability >= 0.60 THEN '🟡 MANUAL REVIEW — High Risk: Senior Underwriter Required'
        WHEN ml_default_probability >= 0.40 THEN '🟠 CONDITIONAL APPROVE — Collateral / Guarantor Required'
        WHEN ml_default_probability >= 0.25 THEN '🟢 APPROVE WITH MONITORING — Medium Risk'
        ELSE '✅ APPROVE — Low Risk Borrower'
    END AS decision_recommendation,
    default_status AS actual_outcome
FROM loan_data
WHERE loan_id = 'LN1000001';  -- ← Replace with any loan_id



-- SECTION 10: EXECUTIVE KPI SUMMARY (for Power BI)

SELECT
    COUNT(*) AS total_loans,
    CAST(ROUND(SUM(loan_amount_inr) / 10000000.0, 2) AS DECIMAL(10,2)) AS total_portfolio_crore,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS defaults,
    CAST(ROUND(100.0 * SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0),
    2) AS DECIMAL(10,2)) AS overall_default_rate_pct,
    ROUND(AVG(credit_score), 0) AS avg_cibil_score,
    ROUND(AVG(dti_ratio), 2) AS avg_dti_ratio,
    CAST(ROUND(AVG(interest_rate), 2) AS DECIMAL(10,2)) AS avg_interest_rate_pct,
    SUM(CASE WHEN ml_risk_flag = 1 THEN 1 ELSE 0 END) AS ml_flagged_high_risk_loans,
    CAST(ROUND(SUM(CASE WHEN ml_risk_flag = 1
              THEN loan_amount_inr * 0.70 ELSE 0 END)
          / 10000000.0, 2) AS DECIMAL(10,2)) AS at_risk_loss_crore,
    SUM(CASE WHEN ml_risk_flag = 1
             AND default_status = 1 THEN 1 ELSE 0 END) AS defaults_that_model_caught
FROM loan_data;
