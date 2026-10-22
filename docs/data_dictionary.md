# Data model and field contract

This is the planned raw-to-analytics contract. Names may be extended during implementation, but entity grains and target rules in `requirements.md` must remain intact unless explicitly revised.

## Relationships

```text
customer 1 ── * application 1 ── 0..1 loan 1 ── * repayment_schedule
                                                     * ── * payment
                                            via payment_allocation
```

## Raw entities

| Table | Required fields | Notes |
|---|---|---|
| `raw_customer` | `customer_id`, `created_at`, `region`, `area_type`, `age_band` | `age_band` is audit-only; synthetic identifier |
| `raw_application` | `application_id`, `customer_id`, `submitted_at`, `decision_at`, `requested_amount_ghs`, `requested_tenor_days`, `channel`, `decision_status` | Status in submitted/approved/declined/withdrawn; application-time fields only for scoring |
| `raw_loan` | `loan_id`, `application_id`, `disbursed_at`, `principal_ghs`, `tenor_days`, `annual_rate`, `product_code`, `loan_status` | One booked loan per approved application in v1 |
| `raw_repayment_schedule` | `schedule_id`, `loan_id`, `installment_no`, `due_date`, `principal_due_ghs`, `interest_due_ghs` | Contractual obligations, not observed behavior |
| `raw_payment` | `payment_id`, `loan_id`, `paid_at`, `amount_ghs`, `channel`, `status` | Events can be partial, late, reversed, or pending |
| `raw_payment_allocation` | `payment_id`, `schedule_id`, `allocated_amount_ghs` | Allocation grain makes installment performance computable |

## Derived analytical tables

| Model | Grain | Key contents |
|---|---|---|
| `dim_customer` | Customer | Stable audit attributes; no direct identifiers |
| `fct_application` | Application | Point-in-time fields and outcome status |
| `fct_loan` | Loan | Contract facts and maturity dates |
| `fct_installment_performance` | Schedule installment | Amount paid by due+grace date, max DPD, first 90+ DPD date |
| `mart_application_outcome` | Booked application/loan | `default_90dpd_180d`, `label_matured_at`, `label_status`, observed loss fields |
| `mart_application_features` | Application | Approved training features explicitly available as of `decision_at` |

## Feature availability contract

For every training feature, record: source field, event timestamp, availability timestamp, and transformation. Exclude disbursement, schedule, repayment, collections, subsequent applications, and any post-decision status from model inputs. Historical repayment features must include only loans whose relevant performance was observable before the current application decision.

## Money and date conventions

- Store monetary values in GHS using fixed-precision numeric values; do not use binary float for SQL money calculations.
- Persist source timestamps with timezone. Analytics can derive Ghana local calendar dates after specifying the timezone conversion.
- Use inclusive calendar-day DPD: `max(0, observation_date - due_date)` after the installment remains unpaid; document any grace period separately.
- Preserve source event rows. Reversals and invalid events are excluded through a transparent, versioned status rule in the transformation layer.
