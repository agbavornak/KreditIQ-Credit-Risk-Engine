CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.run_control (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    observation_as_of_date date NOT NULL
);
INSERT INTO analytics.run_control (singleton, observation_as_of_date)
VALUES (true, CURRENT_DATE)
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS raw.customer (
    customer_id text PRIMARY KEY,
    created_at timestamptz NOT NULL,
    region text,
    area_type text,
    age_band text
);
CREATE TABLE IF NOT EXISTS raw.application (
    application_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES raw.customer(customer_id),
    submitted_at timestamptz NOT NULL,
    decision_at timestamptz NOT NULL,
    requested_amount_ghs numeric(12,2) NOT NULL CHECK (requested_amount_ghs > 0),
    requested_tenor_days integer NOT NULL CHECK (requested_tenor_days > 0),
    channel text,
    decision_status text NOT NULL CHECK (decision_status IN ('approved','declined','withdrawn'))
);
CREATE TABLE IF NOT EXISTS raw.loan (
    loan_id text PRIMARY KEY,
    application_id text NOT NULL UNIQUE REFERENCES raw.application(application_id),
    disbursed_at timestamptz NOT NULL,
    principal_ghs numeric(12,2) NOT NULL CHECK (principal_ghs > 0),
    tenor_days integer NOT NULL CHECK (tenor_days > 0),
    annual_rate numeric(8,5) NOT NULL,
    product_code text NOT NULL,
    loan_status text NOT NULL
);
CREATE TABLE IF NOT EXISTS raw.repayment_schedule (
    schedule_id text PRIMARY KEY,
    loan_id text NOT NULL REFERENCES raw.loan(loan_id),
    installment_no integer NOT NULL CHECK (installment_no > 0),
    due_date date NOT NULL,
    principal_due_ghs numeric(12,2) NOT NULL CHECK (principal_due_ghs >= 0),
    interest_due_ghs numeric(12,2) NOT NULL CHECK (interest_due_ghs >= 0),
    UNIQUE (loan_id, installment_no)
);
CREATE TABLE IF NOT EXISTS raw.payment (
    payment_id text PRIMARY KEY,
    loan_id text NOT NULL REFERENCES raw.loan(loan_id),
    paid_at timestamptz NOT NULL,
    amount_ghs numeric(12,2) NOT NULL CHECK (amount_ghs > 0),
    channel text,
    status text NOT NULL
);
CREATE TABLE IF NOT EXISTS raw.payment_allocation (
    payment_id text NOT NULL REFERENCES raw.payment(payment_id),
    schedule_id text NOT NULL REFERENCES raw.repayment_schedule(schedule_id),
    allocated_amount_ghs numeric(12,2) NOT NULL CHECK (allocated_amount_ghs > 0),
    PRIMARY KEY (payment_id, schedule_id)
);

CREATE INDEX IF NOT EXISTS ix_application_customer_decision ON raw.application(customer_id, decision_at);
CREATE INDEX IF NOT EXISTS ix_loan_disbursed ON raw.loan(disbursed_at);
CREATE INDEX IF NOT EXISTS ix_schedule_loan_due ON raw.repayment_schedule(loan_id, due_date);
CREATE INDEX IF NOT EXISTS ix_payment_loan_paid ON raw.payment(loan_id, paid_at);
