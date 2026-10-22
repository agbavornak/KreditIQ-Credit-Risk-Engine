# Analysis, modeling, and decision plan

## EDA and data trust

1. Reconcile row counts and keys at every entity grain; quantify duplicate keys, orphan joins, and allocation imbalance.
2. Show missingness, category coverage, timestamp order, invalid values, and injected defects before repair.
3. Check application-to-loan conversion, repeat-customer mix, label maturity, and monthly outcome coverage.
4. Calculate default rates only on matured booked loans; include numerator, denominator, and confidence intervals.
5. Compare distributions over time and by product/channel; distinguish descriptive association from cause.

## Feature engineering

Construct an as-of feature snapshot at application decision time. Candidate groups: requested amount and tenor; customer tenure; application history known at decision time; count of prior booked loans; prior completed/on-time/late repayment summaries computed only from past loans with sufficient observation. Keep age band, geography, channel, and device-like fields out of the primary model; consider selected dimensions only for carefully framed audit cuts.

## Validation and models

- Baseline: matured historical default rate, then interpretable regularized logistic regression.
- Candidate: tree-based classifier if supported by out-of-time improvement and stable calibration.
- Split by origination time into train/validation/test; additionally report customer-disjoint performance to expose repeat-customer dependence.
- Fit preprocessing on training data only. Tune only on validation data. Keep final test untouched until model choice is fixed.
- Report ROC-AUC and PR-AUC alongside Brier score, calibration curve/slope, precision/recall at policy thresholds, confusion counts, and confidence intervals where practical.
- Calibrate probabilities on validation data only if needed. A ranking score is not a probability until calibration is assessed.
- Compare features to simple baselines and check leakage, subgroup coverage, stability, and error concentration.

## Expected loss and policy simulation

For application `i`, a first-order credit-loss estimate is `PD_i × EAD_i × LGD_i`. Define exposure at default and loss-given-default assumptions explicitly; do not treat principal as loss without recovery assumptions. Add revenue/funding/operating economics only when those inputs are explicit. Compare thresholds and amount caps on the same eligible applicant population. Report approval rate, booked principal, expected loss, expected loss rate, and good applicants not approved. Uncertainty/sensitivity scenarios are required; no threshold is universally optimal.

## Explainability and monitoring

Explain global and individual predictions using transparent coefficients and/or model-appropriate attribution, with correlated-feature and synthetic-world caveats. Monitoring covers input schema/missingness, population and score drift, calibration once labels mature, default rate by vintage, subgroup performance/coverage, decision rates, and model/policy version. State minimum sample and alert review rules before claiming an alert is actionable.
