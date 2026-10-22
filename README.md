# KreditIQ — Credit Risk & Loan Default Intelligence Engine

KreditIQ is a portfolio project for a fictional Ghanaian digital lender. It follows a loan application from raw operational data through SQL modeling, exploratory analysis, default prediction, risk-based decisions, expected-loss scenarios, and monitoring.

All records are synthetic. The project is for analytical demonstration, not credit underwriting or financial advice. Synthetic patterns cannot establish real Ghanaian borrower behavior.

## Decision this system supports

For an eligible loan application, estimate the risk of serious delinquency and compare approve, price/limit, manual-review, and decline policies under explicit loss and access assumptions. The model is decision support: policy owners retain the final decision.

## Current scope

- Application-level prediction for booked loans with fully observed outcomes.
- Primary target: at least one scheduled installment reaches 90 or more days past due within 180 days after first disbursement.
- Portfolio analysis at customer, application, loan, and installment grains.
- GHS-denominated loan and loss amounts.
- Reproducible synthetic source data and a PostgreSQL-first analytical model.
- Python analysis and modeling; Power BI is the intended presentation layer.

The first version excludes live borrower data, real credit bureau integrations, production deployment, automated adverse decisions, and causal claims about protected or proxy attributes.

## Synthetic data, version 1

Run `python src/generate_data.py` to create six CSV source tables under `data/raw/` (the generated files are intentionally git-ignored). The default seed is `20260928` and the default population is 5,000 synthetic customers. The data includes 30-day to 90-day products, requested amounts based on GHS 300–3,000 tiers with ±15% random variation (approximately GHS 255–3,450), 2–3 scheduled installments, three synthetic channels, and eight synthetic region categories. A customer-level latent risk term, requested amount, tenor, and prior synthetic default status affect generated default probability; outcomes also contain randomness. Approvals are randomly assigned at 78% and are deliberately not risk-ranked, preserving a clear distinction between the outcome mechanism and selection process.

The default run creates roughly 7,400 applications and 5,800 booked loans; counts vary only if the seed/population changes. Payment schedules, event timing, and region shares are invented for project practice and are not market estimates. The generator currently makes a defaulting loan miss its first installment and pay later scheduled installments; non-default installments pay in full with delays under 90 days. This makes the target auditable while keeping repayment behavior intentionally simplified.

## PostgreSQL

Create the raw tables with `sql/001_raw_schema.sql`, import the six CSVs into the matching `raw` tables, then run `sql/002_analytics_views.sql`. The single-row `analytics.run_control` table freezes the maturity cutoff at initial schema setup; set its `observation_as_of_date` explicitly for a reproducible analysis run. PostgreSQL's `\copy` can load each generated CSV with a header. The views expose outcomes and point-in-time feature starters; review target maturity and feature availability before modeling.

## Repository map

```text
data/                 generated source CSVs (git-ignored)
docs/                 requirements, assumptions, definitions, analysis plan
sql/                  PostgreSQL schema and transformations
src/                  deterministic synthetic data generator and analysis code
notebooks/            reviewable EDA and modeling work
powerbi/               dashboard specification and measures
```

## Build sequence

1. Agree and document decision requirements, population, target, entities, and assumptions.
2. Generate synthetic customers, applications, loans, schedules, and payments.
3. Load raw data to PostgreSQL and build validated analytical views.
4. Profile data and perform EDA with explicit denominators and cohort maturity checks.
5. Engineer only point-in-time features; split by time and customer to reduce leakage.
6. Compare a transparent baseline with calibrated classification models.
7. Convert probabilities into expected loss and simulate policies with access, revenue, and loss tradeoffs.
8. Explain model behavior, define monitoring, and design Power BI decision views.
9. Document reproducibility, limitations, and portfolio takeaways.

## Reproducibility

See `docs/requirements.md` and `docs/data_dictionary.md`. Generated data uses a fixed seed and contains no real people or account identifiers. Setup and run commands will be added alongside each implemented phase.
