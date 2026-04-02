#!/usr/bin/env python3
"""Re-register Control Tower OUs to align account region governance.

After changing landing zone governed regions, run this to propagate
the new settings to all accounts. Processes OUs one at a time since
Control Tower only allows one baseline operation at a time.

Usage:
    python ct-reregister-ous.py                  # all OUs (except Security)
    python ct-reregister-ous.py ou-k4pv-zrkq0fya # specific OU by ID
    python ct-reregister-ous.py Production        # specific OU by name
"""
import argparse
import os
import sys
import time

import boto3
from botocore.exceptions import ClientError

CT_HOME_REGION = os.environ.get("CT_HOME_REGION", "us-west-1")
# CT manages Security OU accounts (Audit, Log Archive) directly.
# Skip it by default — override with INCLUDE_SECURITY_OU=1 if needed.
INCLUDE_SECURITY_OU = os.environ.get("INCLUDE_SECURITY_OU", "0") == "1"
POLL_INTERVAL_SECONDS = 30


def get_all_pages(client, method, key, **kwargs):
    paginator = client.get_paginator(method)
    results = []
    for page in paginator.paginate(**kwargs):
        results.extend(page.get(key, []))
    return results


def wait_for_operation(ct_client, operation_id):
    """Poll until a baseline operation completes."""
    while True:
        resp = ct_client.get_baseline_operation(
            operationIdentifier=operation_id
        )
        op = resp["baselineOperation"]
        status = op.get("status", "UNKNOWN")
        op_type = op.get("operationType", "N/A")

        if status in ("SUCCEEDED", "FAILED"):
            return status

        print(
            f"    Operation {operation_id}: {op_type} — {status}, "
            f"waiting {POLL_INTERVAL_SECONDS}s..."
        )
        time.sleep(POLL_INTERVAL_SECONDS)


def collect_all_ous(org_client, parent_id, depth=0):
    """Recursively collect all OUs under a parent."""
    ous = get_all_pages(
        org_client,
        "list_organizational_units_for_parent",
        "OrganizationalUnits",
        ParentId=parent_id,
    )
    all_ous = []
    for ou in ous:
        ou["_depth"] = depth
        all_ous.append(ou)
        all_ous.extend(
            collect_all_ous(org_client, ou["Id"], depth + 1)
        )
    return all_ous


def parse_args():
    parser = argparse.ArgumentParser(
        description="Re-register Control Tower OUs."
    )
    parser.add_argument(
        "ous",
        nargs="*",
        help="OU ID(s) or name(s) to re-register. "
        "If omitted, all OUs are processed.",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    ct_client = boto3.client("controltower", region_name=CT_HOME_REGION)
    org_client = boto3.client("organizations", region_name=CT_HOME_REGION)

    # Get all OUs recursively (top-level + nested)
    root_id = org_client.list_roots()["Roots"][0]["Id"]
    all_ous = collect_all_ous(org_client, root_id)

    # Get all enabled baselines, index by target
    baselines = get_all_pages(
        ct_client, "list_enabled_baselines", "enabledBaselines"
    )

    baselines_by_target = {}
    for bl in baselines:
        target = bl.get("targetIdentifier", "")
        baselines_by_target.setdefault(target, []).append(bl)
        # Also index by the bare OU/account ID at the end of an ARN
        if "/" in target:
            bare_id = target.rsplit("/", 1)[-1]
            baselines_by_target.setdefault(bare_id, []).append(bl)

    # Filter OUs
    if args.ous:
        # Match by ID or name (case-insensitive for names)
        targets = {t.lower() for t in args.ous}
        ou_queue = [
            ou
            for ou in all_ous
            if ou["Id"].lower() in targets
            or ou["Name"].lower() in targets
        ]
        unmatched = targets - {
            ou["Id"].lower() for ou in ou_queue
        } - {ou["Name"].lower() for ou in ou_queue}
        if unmatched:
            print(f"ERROR: No OUs matched: {', '.join(unmatched)}")
            print("\nAvailable OUs:")
            for ou in all_ous:
                indent = "  " + "  " * ou.get("_depth", 0)
                print(f"{indent}{ou['Id']}  {ou['Name']}")
            sys.exit(1)
    else:
        ou_queue = []
        for ou in all_ous:
            if ou["Name"] == "Security" and not INCLUDE_SECURITY_OU:
                print(
                    f"Skipping Security OU ({ou['Id']}) — set "
                    f"INCLUDE_SECURITY_OU=1 to include it."
                )
                continue
            ou_queue.append(ou)

    if not ou_queue:
        print("No OUs to re-register.")
        return

    print(f"\nWill re-register {len(ou_queue)} OU(s):")
    for ou in ou_queue:
        indent = "  " + "  " * ou.get("_depth", 0)
        print(f"{indent}{ou['Id']}  {ou['Name']}")
    print()

    confirm = input("Proceed? [y/N] ").strip().lower()
    if confirm != "y":
        print("Aborted.")
        sys.exit(0)

    succeeded = 0
    failed = 0

    for ou in ou_queue:
        ou_id = ou["Id"]
        ou_name = ou["Name"]
        ou_baselines = baselines_by_target.get(ou_id, [])

        if not ou_baselines:
            print(f"\n[{ou_name}] No enabled baseline found — skipping.")
            continue

        for bl in ou_baselines:
            bl_arn = bl["arn"]
            print(f"\n[{ou_name}] Resetting baseline {bl_arn}...")

            try:
                resp = ct_client.reset_enabled_baseline(
                    enabledBaselineIdentifier=bl_arn
                )
                operation_id = resp["operationIdentifier"]
                print(f"    Operation started: {operation_id}")

                status = wait_for_operation(ct_client, operation_id)
                if status == "SUCCEEDED":
                    print(f"    [{ou_name}] Re-register SUCCEEDED.")
                    succeeded += 1
                else:
                    print(f"    [{ou_name}] Re-register FAILED.")
                    failed += 1
            except ClientError as e:
                print(f"    [{ou_name}] Error: {e}")
                failed += 1

    print(f"\nDone. Succeeded: {succeeded}, Failed: {failed}")
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()