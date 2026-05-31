#!/usr/bin/env python3
"""
vm-cost-report.py — Query OpenStack Nova for all instances, compare actual
flavor usage vs rightsizing recommendations, and output a cost savings report.

Usage:
    export OS_AUTH_URL OS_USERNAME OS_PASSWORD OS_PROJECT_NAME
    python3 vm-cost-report.py [--output csv|json|table]
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Optional

import openstack

FLAVOR_COSTS_PER_HOUR = {
    "m1.tiny":    0.01,
    "m1.small":   0.03,
    "m1.medium":  0.06,
    "m1.large":   0.12,
    "m1.xlarge":  0.24,
    "m1.2xlarge": 0.48,
}

DOWNSIZE_MAP = {
    "m1.xlarge":  "m1.large",
    "m1.large":   "m1.medium",
    "m1.medium":  "m1.small",
    "m1.small":   "m1.tiny",
}


def get_instances(conn: openstack.connection.Connection) -> list:
    return list(conn.compute.servers(all_projects=True, details=True))


def get_rightsizing_data(instance_id: str) -> Optional[dict]:
    """
    In production, this reads the metrics JSON written by the Ansible
    collect-metrics.sh script, fetched via SSH or a metrics API.
    Returns None if no data available.
    """
    path = f"/var/log/rightsizing/{instance_id}.json"
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return None


def build_report(conn: openstack.connection.Connection) -> list:
    instances = get_instances(conn)
    rows = []

    for inst in instances:
        flavor_name = inst.flavor.get("original_name", "unknown")
        current_cost = FLAVOR_COSTS_PER_HOUR.get(flavor_name, 0.0)
        metrics = get_rightsizing_data(inst.id)

        recommendation = metrics["recommendation"] if metrics else "no-data"
        savings_per_month = 0.0

        if recommendation == "downsize" and flavor_name in DOWNSIZE_MAP:
            new_flavor = DOWNSIZE_MAP[flavor_name]
            new_cost   = FLAVOR_COSTS_PER_HOUR.get(new_flavor, 0.0)
            savings_per_month = (current_cost - new_cost) * 24 * 30
        elif recommendation == "upsize":
            savings_per_month = 0.0

        rows.append({
            "instance_id":         inst.id,
            "instance_name":       inst.name,
            "project_id":          inst.project_id,
            "flavor":              flavor_name,
            "status":              inst.status,
            "cpu_avg_pct":         metrics["cpu_avg_pct"] if metrics else None,
            "mem_pct":             metrics["mem_pct"] if metrics else None,
            "recommendation":      recommendation,
            "savings_eur_month":   round(savings_per_month, 2),
            "report_time":         datetime.now(timezone.utc).isoformat(),
        })

    return rows


def print_table(rows: list):
    headers = ["Name", "Flavor", "CPU%", "Mem%", "Recommendation", "Savings €/mo"]
    print(f"{'─'*90}")
    print(f"{'Name':<30} {'Flavor':<14} {'CPU%':>6} {'Mem%':>6} {'Recommendation':<15} {'Savings €/mo':>12}")
    print(f"{'─'*90}")
    for r in rows:
        cpu = f"{r['cpu_avg_pct']:.1f}" if r["cpu_avg_pct"] is not None else "N/A"
        mem = f"{r['mem_pct']:.1f}"     if r["mem_pct"] is not None else "N/A"
        print(f"{r['instance_name']:<30} {r['flavor']:<14} {cpu:>6} {mem:>6} {r['recommendation']:<15} {r['savings_eur_month']:>12.2f}")
    print(f"{'─'*90}")
    total = sum(r["savings_eur_month"] for r in rows)
    print(f"{'TOTAL POTENTIAL SAVINGS':>68} {total:>12.2f} €/mo")


def main():
    parser = argparse.ArgumentParser(description="OpenStack VM cost & rightsizing report")
    parser.add_argument("--output", choices=["table", "json", "csv"], default="table")
    args = parser.parse_args()

    conn = openstack.connect()
    rows = build_report(conn)

    if args.output == "json":
        print(json.dumps(rows, indent=2))
    elif args.output == "csv":
        import csv, io
        out = io.StringIO()
        writer = csv.DictWriter(out, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
        print(out.getvalue())
    else:
        print_table(rows)


if __name__ == "__main__":
    main()
