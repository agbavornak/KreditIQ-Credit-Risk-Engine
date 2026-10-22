-- Payment events with a settled status reduce an installment's contractual balance.
-- This demo's synthetic source contains no reversal rows; real data needs a canonical
-- reversal/chargeback rule before this view is used.
CREATE OR REPLACE VIEW analytics.installment_performance AS
WITH paid AS (
    SELECT a.schedule_id,
           SUM(a.allocated_amount_ghs) FILTER (WHERE p.status = 'settled') AS settled_total,
           SUM(a.allocated_amount_ghs) FILTER (
               WHERE p.status = 'settled'
                 AND (p.paid_at AT TIME ZONE 'Africa/Accra')::date <= s.due_date + 90
           ) AS settled_by_90d
    FROM raw.repayment_schedule s
    LEFT JOIN raw.payment_allocation a ON a.schedule_id = s.schedule_id
    LEFT JOIN raw.payment p ON p.payment_id = a.payment_id
    GROUP BY a.schedule_id
), base AS (
    SELECT s.schedule_id, s.loan_id, s.installment_no, s.due_date,
           s.principal_due_ghs + s.interest_due_ghs AS amount_due_ghs,
           COALESCE(p.settled_total, 0) AS settled_total_ghs,
           COALESCE(p.settled_by_90d, 0) AS settled_by_90d_ghs,
           (l.disbursed_at AT TIME ZONE 'Africa/Accra')::date AS disbursed_date
    FROM raw.repayment_schedule s
    JOIN raw.loan l ON l.loan_id = s.loan_id
    LEFT JOIN paid p ON p.schedule_id = s.schedule_id
)
SELECT *,
       GREATEST(amount_due_ghs - settled_by_90d_ghs, 0) AS balance_at_90d_ghs,
       CASE WHEN amount_due_ghs > settled_by_90d_ghs + 0.01
            THEN due_date + 90 END AS first_90dpd_date
FROM base;

-- Set observation_as_of deliberately when running a reproducible analysis.
-- The view uses current_date for convenience; freeze it in a run parameter/table
-- for historical reproducibility and avoid using today's date in model features.
CREATE OR REPLACE VIEW analytics.application_outcome AS
WITH loan_events AS (
    SELECT l.loan_id, l.application_id,
           (l.disbursed_at AT TIME ZONE 'Africa/Accra')::date AS disbursed_date,
           MIN(ip.first_90dpd_date) FILTER (
               WHERE ip.first_90dpd_date <= l.disbursed_at::date + 180
           ) AS event_date,
           BOOL_AND(ip.due_date + 90 <= rc.observation_as_of_date) AS schedule_observed
    FROM raw.loan l
    JOIN analytics.installment_performance ip ON ip.loan_id = l.loan_id
    CROSS JOIN analytics.run_control rc
    GROUP BY l.loan_id, l.application_id, l.disbursed_at
), labels AS (
    SELECT *,
           (rc.observation_as_of_date >= disbursed_date + 180 AND schedule_observed) AS outcome_matured
    FROM loan_events
    CROSS JOIN analytics.run_control rc
)
SELECT a.application_id, a.customer_id, a.submitted_at, a.decision_at,
       a.requested_amount_ghs, a.requested_tenor_days, a.channel, a.decision_status,
       l.loan_id, l.disbursed_date, l.event_date,
       CASE WHEN l.loan_id IS NULL THEN NULL
            WHEN NOT l.outcome_matured THEN NULL
            WHEN l.event_date IS NOT NULL THEN 1 ELSE 0 END AS default_90dpd_180d,
       CASE WHEN l.loan_id IS NULL THEN 'not_booked'
            WHEN NOT l.outcome_matured THEN 'immature'
            ELSE 'matured' END AS label_status
FROM raw.application a
LEFT JOIN labels l ON l.application_id = a.application_id;

-- Point-in-time starter mart. age/geography are deliberately not included as model inputs.
-- Prior-loan features must only use loans fully observable before decision_at.
CREATE OR REPLACE VIEW analytics.application_features AS
SELECT a.application_id, a.customer_id, a.decision_at,
       a.requested_amount_ghs, a.requested_tenor_days, a.channel,
       c.created_at AS customer_created_at,
           ((a.decision_at AT TIME ZONE 'Africa/Accra')::date -
            (c.created_at AT TIME ZONE 'Africa/Accra')::date) AS customer_tenure_days,
       COUNT(prev.loan_id) AS prior_booked_loans,
       COUNT(prev.loan_id) FILTER (
           WHERE prev_out.default_90dpd_180d = 1
       ) AS prior_matured_defaults
FROM raw.application a
JOIN raw.customer c ON c.customer_id = a.customer_id
LEFT JOIN raw.application prior_a
       ON prior_a.customer_id = a.customer_id
      AND prior_a.decision_at < a.decision_at
LEFT JOIN raw.loan prev ON prev.application_id = prior_a.application_id
LEFT JOIN analytics.application_outcome prev_out
       ON prev_out.application_id = prior_a.application_id
      AND prev_out.label_status = 'matured'
      AND prev_out.disbursed_date + 180 <= (a.decision_at AT TIME ZONE 'Africa/Accra')::date
GROUP BY a.application_id, a.customer_id, a.decision_at,
         a.requested_amount_ghs, a.requested_tenor_days, a.channel, c.created_at;
