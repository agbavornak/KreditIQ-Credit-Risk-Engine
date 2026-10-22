-- Run after loading all six raw CSVs. These are review queries, not automatic repairs.

-- Expected entity counts and key uniqueness (PK constraints should also enforce this).
SELECT 'customer' AS entity, COUNT(*) AS rows, COUNT(DISTINCT customer_id) AS distinct_keys FROM raw.customer
UNION ALL SELECT 'application', COUNT(*), COUNT(DISTINCT application_id) FROM raw.application
UNION ALL SELECT 'loan', COUNT(*), COUNT(DISTINCT loan_id) FROM raw.loan
UNION ALL SELECT 'schedule', COUNT(*), COUNT(DISTINCT schedule_id) FROM raw.repayment_schedule
UNION ALL SELECT 'payment', COUNT(*), COUNT(DISTINCT payment_id) FROM raw.payment;

-- Timestamp and application/loan consistency.
SELECT COUNT(*) AS decisions_before_submission
FROM raw.application WHERE decision_at < submitted_at;
SELECT a.decision_status, COUNT(*) AS applications,
       COUNT(l.loan_id) AS linked_loans
FROM raw.application a LEFT JOIN raw.loan l USING (application_id)
GROUP BY a.decision_status ORDER BY a.decision_status;

-- Allocation integrity: identify payment-to-loan mismatches and amount over-allocation.
SELECT COUNT(*) AS mismatched_payment_loan_allocations
FROM raw.payment_allocation a
JOIN raw.payment p USING (payment_id)
JOIN raw.repayment_schedule s USING (schedule_id)
WHERE p.loan_id <> s.loan_id;
SELECT p.payment_id, p.amount_ghs, SUM(a.allocated_amount_ghs) AS allocated_ghs
FROM raw.payment p JOIN raw.payment_allocation a USING (payment_id)
GROUP BY p.payment_id, p.amount_ghs
HAVING SUM(a.allocated_amount_ghs) > p.amount_ghs + 0.01;

-- Label denominator and monthly outcome maturity; always show unknowns.
SELECT label_status, default_90dpd_180d, COUNT(*) AS applications
FROM analytics.application_outcome
GROUP BY label_status, default_90dpd_180d
ORDER BY label_status, default_90dpd_180d;
SELECT date_trunc('month', submitted_at AT TIME ZONE 'Africa/Accra')::date AS origination_month,
       COUNT(*) AS applications,
       COUNT(*) FILTER (WHERE label_status = 'matured') AS matured_booked,
       COUNT(*) FILTER (WHERE default_90dpd_180d = 1) AS qualifying_defaults
FROM analytics.application_outcome
GROUP BY 1 ORDER BY 1;

-- Negative tenure, missing schedules, or impossible label times need investigation.
SELECT COUNT(*) AS negative_customer_tenure
FROM analytics.application_features WHERE customer_tenure_days < 0;
SELECT l.loan_id
FROM raw.loan l LEFT JOIN raw.repayment_schedule s USING (loan_id)
GROUP BY l.loan_id HAVING COUNT(s.schedule_id) = 0;
