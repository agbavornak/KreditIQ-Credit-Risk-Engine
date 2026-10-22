"""Create deterministic, wholly synthetic KreditIQ source tables."""

from __future__ import annotations

import argparse
import csv
import math
import random
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


def sigmoid(value: float) -> float:
    return 1 / (1 + math.exp(-value))


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def generate(out: Path, customers_n: int, seed: int) -> dict[str, int]:
    rng = random.Random(seed)
    customers, applications, loans, schedules, payments, allocations = [], [], [], [], [], []
    risk_by_customer: dict[str, float] = {}
    start = date(2023, 1, 1)
    regions = ["Greater Accra", "Ashanti", "Eastern", "Central", "Northern", "Western", "Volta", "Other"]

    for idx in range(1, customers_n + 1):
        cid = f"C{idx:07d}"
        created = start + timedelta(days=rng.randint(0, 850))
        risk = rng.gauss(0, 0.75)
        risk_by_customer[cid] = risk
        customers.append({
            "customer_id": cid,
            "created_at": datetime.combine(created, datetime.min.time(), timezone.utc).isoformat(),
            "region": rng.choices(regions, [0.34, .18, .09, .08, .08, .08, .06, .09])[0],
            "area_type": rng.choices(["urban", "peri_urban", "rural"], [.55, .28, .17])[0],
            "age_band": rng.choices(["18-24", "25-34", "35-44", "45+"], [.22, .43, .23, .12])[0],
        })

    app_no = 0
    for customer in customers:
        cid = customer["customer_id"]
        count = 1 + (rng.random() < .38) + (rng.random() < .10)
        prior_default = 0
        for seq in range(int(count)):
            app_no += 1
            aid = f"A{app_no:08d}"
            sampled_day = date(2023, 1, 1) + timedelta(days=rng.randint(0, 1030) + seq * 150)
            submitted_day = max(sampled_day, datetime.fromisoformat(customer["created_at"]).date())
            submitted = datetime.combine(submitted_day, datetime.min.time(), timezone.utc) + timedelta(minutes=rng.randint(0, 1439))
            decision = submitted + timedelta(minutes=rng.randint(2, 240))
            requested = round(rng.choice([300, 500, 750, 1000, 1500, 2000, 3000]) * rng.uniform(.85, 1.15), 2)
            tenor = rng.choice([30, 45, 60, 90])
            channel = rng.choices(["app", "web", "agent_assisted"], [.76, .17, .07])[0]
            logit = -2.25 + risk_by_customer[cid] + .00028 * requested + .009 * (tenor - 45) + .85 * prior_default
            default = rng.random() < sigmoid(logit)
            status = "approved" if rng.random() < .78 else "declined"
            # Create observable loan outcomes only for approved applications.
            if status == "approved":
                lid = f"L{len(loans) + 1:08d}"
                disbursed = submitted_day + timedelta(days=1)
                principal = round(requested * rng.uniform(.70, 1.0), 2)
                rate = round(rng.uniform(.18, .42), 4)
                loans.append({"loan_id": lid, "application_id": aid, "disbursed_at": datetime.combine(disbursed, datetime.min.time(), timezone.utc).isoformat(), "principal_ghs": f"{principal:.2f}", "tenor_days": tenor, "annual_rate": f"{rate:.4f}", "product_code": "DIGITAL_CASH", "loan_status": "completed" if not default else "delinquent"})
                installments = 3 if tenor >= 60 else 2
                installment_principal = round(principal / installments, 2)
                for inst in range(1, installments + 1):
                    sid = f"S{len(schedules) + 1:09d}"
                    due = disbursed + timedelta(days=round(tenor * inst / installments))
                    int_due = round(principal * rate * tenor / 365 / installments, 2)
                    schedules.append({"schedule_id": sid, "loan_id": lid, "installment_no": inst, "due_date": due.isoformat(), "principal_due_ghs": f"{installment_principal:.2f}", "interest_due_ghs": f"{int_due:.2f}"})
                    if default and inst == 1:
                        continue
                    delay = rng.choices([0, 3, 14, 35], [.55, .22, .16, .07])[0]
                    paid_date = due + timedelta(days=delay)
                    pid = f"P{len(payments) + 1:09d}"
                    amount = installment_principal + int_due
                    payments.append({"payment_id": pid, "loan_id": lid, "paid_at": datetime.combine(paid_date, datetime.min.time(), timezone.utc).isoformat(), "amount_ghs": f"{amount:.2f}", "channel": rng.choice(["mobile_money", "bank", "wallet"]), "status": "settled"})
                    allocations.append({"payment_id": pid, "schedule_id": sid, "allocated_amount_ghs": f"{amount:.2f}"})
                if default:
                    prior_default = 1
            applications.append({"application_id": aid, "customer_id": cid, "submitted_at": submitted.isoformat(), "decision_at": decision.isoformat(), "requested_amount_ghs": f"{requested:.2f}", "requested_tenor_days": tenor, "channel": channel, "decision_status": status})

    tables = {
        "raw_customer.csv": (customers, ["customer_id", "created_at", "region", "area_type", "age_band"]),
        "raw_application.csv": (applications, ["application_id", "customer_id", "submitted_at", "decision_at", "requested_amount_ghs", "requested_tenor_days", "channel", "decision_status"]),
        "raw_loan.csv": (loans, ["loan_id", "application_id", "disbursed_at", "principal_ghs", "tenor_days", "annual_rate", "product_code", "loan_status"]),
        "raw_repayment_schedule.csv": (schedules, ["schedule_id", "loan_id", "installment_no", "due_date", "principal_due_ghs", "interest_due_ghs"]),
        "raw_payment.csv": (payments, ["payment_id", "loan_id", "paid_at", "amount_ghs", "channel", "status"]),
        "raw_payment_allocation.csv": (allocations, ["payment_id", "schedule_id", "allocated_amount_ghs"]),
    }
    for filename, (rows, fields) in tables.items():
        write_csv(out / filename, rows, fields)
    return {name.removesuffix(".csv"): len(rows) for name, (rows, _) in tables.items()}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--customers", type=int, default=5000)
    parser.add_argument("--seed", type=int, default=20260928)
    parser.add_argument("--out", type=Path, default=Path("data/raw"))
    args = parser.parse_args()
    counts = generate(args.out, args.customers, args.seed)
    for table, count in counts.items():
        print(f"{table}: {count:,} rows")


if __name__ == "__main__":
    main()
