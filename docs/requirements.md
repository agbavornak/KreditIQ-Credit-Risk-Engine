# Business requirements and analytical contract

## 1. Business context

KreditIQ is a fictional Ghanaian digital lender offering short-tenor, GHS-denominated loans through a mobile-first application flow. The analytics team needs to estimate credit risk before disbursement and understand how alternative decision rules affect portfolio loss and customer access.

This is an educational simulation. Ghana-specific operational details below are modeling assumptions, not claims about any real lender, regulation, or population.

## 2. Decision, users, and action

| Item | Definition |
|---|---|
| Decision | Which eligible applications should be approved, assigned a lower limit, sent for manual review, or declined under a stated policy? |
| Users | Risk analyst, credit policy lead, portfolio manager, and model reviewer |
| Unit at decision time | One submitted application, scored using information available by its decision timestamp |
| Actions | Approve at requested or reduced amount; manual review; decline |
| Required evidence | Matured outcome rate, calibrated risk, expected loss, approval rate, booked volume, and subgroup performance/coverage |

The model estimates risk; it does not determine a universally correct risk appetite. Scenario recommendations must state policy thresholds, loss assumptions, and access consequences.

## 3. Scope

### In scope

- Synthetic source-data generation with explicit lineage and reproducible seed.
- Relational model for customers, applications, loans, repayment schedules, and payments.
- Point-in-time application features, matured target construction, and cohort analysis.
- Exploratory and statistical analysis with uncertainty and denominator checks.
- Baseline and machine-learning default prediction, calibration, temporal validation, and segment review.
- Risk bands, expected-loss scenarios, decision simulation, explainability, model monitoring, and Power BI design.
- GitHub-ready documentation and reproducible run instructions.

### Out of scope for version 1

- Real personal, bank, mobile-money, device, or credit-bureau data.
- Production lending decisions, collections strategy, pricing deployment, or loan servicing.
- A claim that a synthetic model is suitable for any actual Ghanaian borrower or lender.
- Causal inference from observational/synthetic associations.
- Making protected traits or their proxies operational decision features. Sensitive/proxy-like fields, if retained for fairness review, are isolated from training inputs.

## 4. Analytical questions

1. What share of disbursed applications has a fully observable 180-day outcome, by origination month and product?
2. What is the 90+ DPD event rate among matured booked loans, and how does it vary by loan size, tenor, repeat-loan status, and prior observed repayment performance?
3. Which pre-decision characteristics add predictive value beyond a simple historical-rate baseline?
4. How well do risk estimates rank and calibrate on later origination cohorts and previously unseen customers?
5. At plausible thresholds, what are approval rate, booked principal, expected credit loss, and missed-good / approved-bad counts?
6. How sensitive are policy outcomes to recovery, funding cost, and loss-given-default assumptions?
7. Do performance, data coverage, calibration, or error rates vary materially across monitored customer segments?
8. What drift, outcome delay, and operational checks would signal that the model or policy needs review?

These questions describe measurements. They do not presume that an observed association is causal or that one group difference justifies a different treatment.

## 5. Target and observation rules

**Prediction timestamp:** application decision timestamp, before disbursement.

**Population:** applications resulting in a disbursed loan. Declined applications have no repayment outcome and are not labeled as non-defaults. This creates approval-selection bias; results apply to the historical booked population and cannot establish risk for rejected applicants without additional labels or a defensible design.

**Positive label:** `default_90dpd_180d = 1` if any contractual installment for the loan first reaches at least 90 days past due during the 180 calendar days after the loan's first disbursement date.

**Negative label:** `0` only when the full 180-day outcome window has elapsed and source records are complete, with no qualifying event.

**Censoring:** applications whose outcome window has not ended, or whose loan/payment history is incomplete, are unlabeled (`NULL`) and excluded from supervised training/evaluation. Do not label them zero.

**Grain:** one label per booked application/loan. Restructures, reversals, and duplicate events require explicit canonicalization in the SQL layer before label creation.

The 90+ DPD threshold and 180-day observation window are project choices to make the target auditable, not a statement of a Ghanaian regulatory default definition.

## 6. Realistic synthetic-data assumptions

| Area | Version 1 assumption |
|---|---|
| Currency | Ghana cedi (GHS); amounts stored as numeric, never inferred from strings |
| Products | Small digital cash loans with short tenors; configurable principal and term distributions |
| Geography | Broad Ghana regions and urban/rural-like service areas as synthetic categories; no claim of representative coverage |
| Acquisition | Mobile-first applications; application/device/channel fields are synthetic and potentially proxy-like |
| Customers | Some repeat applications and prior completed loans; stable customer key across records |
| Repayment | Scheduled installments with partial, late, on-time, and missed payments; payment events may settle more than one installment |
| Timing | Timestamped application, decision, disbursement, due date, and payment event; all features must be available by decision time |
| Risk process | Outcome generation uses a hidden synthetic mechanism plus randomness; a subset of fields is predictive, weakly predictive, or irrelevant so modeling can be challenged |
| Data quality | Controlled missingness, duplicates, and late events may be injected deliberately and documented; do not silently clean away evidence |
| Fairness | Age and geography may be retained only for coverage/error audits; never use direct sensitive or proxy-like attributes as model inputs in the primary model |

Amounts, rates, product terms, population mix, and default prevalence will be disclosed in generator configuration and README once the generator is built. They must not be described as estimates of Ghana market values.

## 7. Entities and grains

| Entity | Grain | Key | Main purpose |
|---|---|---|---|
| Customer | One synthetic person/account | `customer_id` | Stable, minimal customer attributes and tenure |
| Application | One credit request | `application_id` | Point-in-time requested amount, channel, application and decision timestamps/status |
| Loan | One disbursement contract | `loan_id` | Approved amount, product, tenor, disbursement date, contractual terms |
| Repayment schedule | One installment due for a loan | `schedule_id` | Due date, principal/interest due, contractual installment sequence |
| Payment | One recorded payment event | `payment_id` | Payment timestamp, amount, channel, event status; allocated amount modeled explicitly |
| Payment allocation | One payment-to-installment allocation | composite key | Supports split payments and a payment covering multiple installments |

Applications may be declined or withdrawn and therefore have no loan. Each loan links to one booked application in version 1. A customer may have multiple applications and loans over time.

## 8. Success criteria

- A reviewer can reproduce synthetic inputs and trace every modeled field to source entities and an as-of rule.
- Target labels distinguish positive, mature negative, and censored/unknown outcomes.
- Evaluation uses chronological holdout data and customer-aware checks; no post-decision fields leak into features.
- Model quality includes discrimination, calibration, threshold metrics, and uncertainty/context, not accuracy alone.
- Policy scenarios report outcomes per application and per booked principal, with assumptions visible.
- Dashboard shows portfolio denominator, maturity/coverage, risk, loss, decision policy, and monitoring status.
- Documentation makes limitations and intended educational use prominent.

## 9. Risks and open design questions

Selection bias among booked loans, synthetic-to-real gap, outcome-window choice, proxy leakage, class imbalance, temporal drift, and uncertain recovery economics are first-order risks. They must appear in analysis and documentation, not be buried as implementation notes.

Open decisions for review as the project proceeds: whether to model a single-installment or multi-installment product; how to define economic loss versus principal-at-default; and which subgroup dimensions are appropriate for audit. Defaults in the first generator will be stated explicitly and revisable.
