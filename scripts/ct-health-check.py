#!/usr/bin/env python3
"""Control Tower health check script.

Checks landing zone status, account enrollment, region governance,
enabled controls, Security Hub findings, CloudTrail, and Config compliance.
"""
import json
import os
import sys
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

CT_HOME_REGION = os.environ.get("CT_HOME_REGION", "us-west-1")
GOVERNED_REGIONS = ["us-east-1", "us-east-2", "us-west-1", "us-west-2"]


def section(title):
    print(f"\n--- {title} ---")


def warn(msg):
    print(f"    WARNING: {msg}")


def info(msg):
    print(f"    {msg}")


def get_all_pages(client, method, key, **kwargs):
    """Generic paginator for AWS APIs that return a next token."""
    paginator = client.get_paginator(method)
    results = []
    for page in paginator.paginate(**kwargs):
        results.extend(page.get(key, []))
    return results


def check_landing_zone(ct_client):
    section("Landing Zone")
    landing_zones = ct_client.list_landing_zones().get("landingZones", [])
    if not landing_zones:
        print("ERROR: No landing zone found.")
        sys.exit(1)

    lz_arn = landing_zones[0]["arn"]
    print(f"Landing Zone ARN: {lz_arn}")

    lz = ct_client.get_landing_zone(landingZoneIdentifier=lz_arn)["landingZone"]
    print(f"  Status:       {lz['status']}")
    print(f"  Version:      {lz.get('version', 'N/A')}")
    print(f"  Drift Status: {lz.get('driftStatus', {}).get('status', 'N/A')}")

    lz_governed = lz.get("manifest", {}).get("governedRegions", [])
    print(f"  Governed Regions: {', '.join(sorted(lz_governed))}")

    return lz_arn, sorted(lz_governed)


def check_landing_zone_operations(ct_client):
    section("Recent Landing Zone Operations")
    try:
        ops = ct_client.list_landing_zone_operations().get(
            "landingZoneOperations", []
        )
        if not ops:
            info("No operations found.")
            return
        for op in ops[:5]:
            op_id = op.get("operationIdentifier", "N/A")
            op_type = op.get("operationType", "N/A")
            status = op.get("status", "N/A")
            marker = " <<<" if status == "FAILED" else ""
            print(f"    {op_id}  {op_type:10s}  {status}{marker}")
    except ClientError:
        info("Could not retrieve operations.")


def check_enabled_controls(ct_client):
    section("Enabled Controls Summary")
    try:
        controls = get_all_pages(
            ct_client, "list_enabled_controls", "enabledControls"
        )
        print(f"  Total enabled controls: {len(controls)}")

        problem_controls = [
            c
            for c in controls
            if c.get("statusSummary", {}).get("status") != "SUCCEEDED"
        ]
        if problem_controls:
            print("  Controls with drift or failed status:")
            for c in problem_controls:
                ident = c.get("controlIdentifier", "N/A")
                status = c.get("statusSummary", {}).get("status", "N/A")
                warn(f"{ident} — {status}")
        else:
            info("All controls in SUCCEEDED state.")
    except ClientError as e:
        info(f"Could not list controls: {e}")


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


def check_organization(org_client):
    section("Organization Structure")
    roots = org_client.list_roots()["Roots"]
    root_id = roots[0]["Id"]
    print(f"  Root ID: {root_id}")

    ous = collect_all_ous(org_client, root_id)
    print("\n  OUs (including nested):")
    for ou in ous:
        indent = "    " + "  " * ou.get("_depth", 0)
        print(f"{indent}{ou['Id']}  {ou['Name']}")

    return root_id, ous


def check_accounts(org_client):
    section("Organization Accounts")
    accounts = get_all_pages(org_client, "list_accounts", "Accounts")
    for acct in accounts:
        print(
            f"    {acct['Id']}  {acct['Status']:8s}  {acct['Name']}"
            f"  ({acct.get('Email', '')})"
        )
    return accounts


def check_account_enrollment(ct_client, org_client, root_id, ous, lz_governed):
    section("Account Enrollment & Region Governance")

    try:
        baselines = get_all_pages(
            ct_client, "list_enabled_baselines", "enabledBaselines"
        )
    except ClientError as e:
        info(f"Could not list baselines: {e}")
        return

    # Index baselines by target
    baselines_by_target = {}
    for bl in baselines:
        target = bl.get("targetIdentifier", "")
        baselines_by_target.setdefault(target, []).append(bl)

    accounts_needing_update = []
    accounts_mixed_governance = []

    for ou in ous:
        ou_id = ou["Id"]
        ou_name = ou["Name"]

        ou_accounts = get_all_pages(
            org_client,
            "list_accounts_for_parent",
            "Accounts",
            ParentId=ou_id,
        )

        for acct in ou_accounts:
            acct_id = acct["Id"]
            acct_name = acct["Name"]
            label = f"{acct_name} ({acct_id}) in OU {ou_name}"

            acct_baselines = baselines_by_target.get(acct_id, [])

            # Check if any baseline is not SUCCEEDED
            for bl in acct_baselines:
                status = bl.get("statusSummary", {}).get("status", "")
                if status != "SUCCEEDED":
                    accounts_needing_update.append(
                        f"{label} — baseline status: {status}"
                    )
                    break

            # Check governed regions from baseline parameters
            for bl in acct_baselines:
                params = bl.get("parameters", [])
                for param in params:
                    if param.get("key") == "GovernedRegions":
                        acct_regions = sorted(param.get("value", []))
                        if acct_regions != lz_governed:
                            accounts_mixed_governance.append(
                                f"{label}\n"
                                f"        Account regions: "
                                f"{', '.join(acct_regions)}\n"
                                f"        LZ regions:      "
                                f"{', '.join(lz_governed)}"
                            )
                        break

    print("\n  Accounts needing baseline update:")
    if accounts_needing_update:
        for msg in accounts_needing_update:
            warn(msg)
    else:
        info("None.")

    print("\n  Accounts with mixed region governance:")
    if accounts_mixed_governance:
        for msg in accounts_mixed_governance:
            warn(msg)
    else:
        info("None detected via baselines (check CT console to confirm).")


def check_security_hub(region):
    sh_client = boto3.client("securityhub", region_name=region)

    try:
        sh_client.describe_hub()
    except ClientError:
        info("Security Hub not enabled.")
        return

    severities = ["CRITICAL", "HIGH", "MEDIUM"]
    counts = {}

    for severity in severities:
        try:
            findings = sh_client.get_findings(
                Filters={
                    "ComplianceStatus": [
                        {"Value": "FAILED", "Comparison": "EQUALS"}
                    ],
                    "SeverityLabel": [
                        {"Value": severity, "Comparison": "EQUALS"}
                    ],
                    "RecordState": [
                        {"Value": "ACTIVE", "Comparison": "EQUALS"}
                    ],
                    "WorkflowStatus": [
                        {"Value": "NEW", "Comparison": "EQUALS"},
                        {"Value": "NOTIFIED", "Comparison": "EQUALS"},
                    ],
                },
            )
            counts[severity] = len(findings.get("Findings", []))
        except ClientError:
            counts[severity] = "?"

    summary = ", ".join(f"{s}: {counts[s]}" for s in severities)
    info(f"Failed findings — {summary}")

    # Detail critical/high
    crit_high = (counts.get("CRITICAL") or 0) + (counts.get("HIGH") or 0)
    if isinstance(crit_high, int) and crit_high > 0:
        try:
            findings = sh_client.get_findings(
                Filters={
                    "ComplianceStatus": [
                        {"Value": "FAILED", "Comparison": "EQUALS"}
                    ],
                    "SeverityLabel": [
                        {"Value": "CRITICAL", "Comparison": "EQUALS"},
                        {"Value": "HIGH", "Comparison": "EQUALS"},
                    ],
                    "RecordState": [
                        {"Value": "ACTIVE", "Comparison": "EQUALS"}
                    ],
                    "WorkflowStatus": [
                        {"Value": "NEW", "Comparison": "EQUALS"},
                        {"Value": "NOTIFIED", "Comparison": "EQUALS"},
                    ],
                },
            )
            info("Critical/High finding details:")
            for f in findings.get("Findings", []):
                title = f.get("Title", "N/A")
                sev = f.get("Severity", {}).get("Label", "N/A")
                acct = f.get("AwsAccountId", "N/A")
                res = (
                    f.get("Resources", [{}])[0].get("Id", "N/A")
                    if f.get("Resources")
                    else "N/A"
                )
                print(f"      [{sev}] {title}")
                print(f"        Account: {acct}  Resource: {res}")
        except ClientError:
            info("Could not retrieve finding details.")


def check_security_hub_all_regions():
    section("Security Hub: CT Standard Findings (per governed region)")
    for region in GOVERNED_REGIONS:
        print(f"\n  Region: {region}")
        check_security_hub(region)


def check_cloudtrail(region):
    section("Control Tower CloudTrail")
    ct_trail = boto3.client("cloudtrail", region_name=region)
    try:
        status = ct_trail.get_trail_status(
            Name="aws-controltower-BaselineCloudTrail"
        )
        is_logging = status.get("IsLogging", False)
        last_delivery = status.get("LatestDeliveryTime", "N/A")
        last_error = status.get("LatestDeliveryError", "None")
        print(f"  Is Logging:          {is_logging}")
        print(f"  Latest Delivery:     {last_delivery}")
        print(f"  Latest Delivery Err: {last_error}")
    except ClientError as e:
        info(f"Could not get CloudTrail status: {e}")


def check_config_compliance():
    section("AWS Config Non-Compliant Rules (per governed region)")
    for region in GOVERNED_REGIONS:
        print(f"\n  Region: {region}")
        config_client = boto3.client("config", region_name=region)
        try:
            rules = get_all_pages(
                config_client,
                "describe_compliance_by_config_rule",
                "ComplianceByConfigRules",
            )
            non_compliant = [
                r
                for r in rules
                if r.get("Compliance", {}).get("ComplianceType") != "COMPLIANT"
            ]
            if non_compliant:
                for r in non_compliant:
                    name = r.get("ConfigRuleName", "N/A")
                    status = r.get("Compliance", {}).get(
                        "ComplianceType", "N/A"
                    )
                    warn(f"{name} — {status}")
            else:
                info("All rules compliant.")
        except ClientError as e:
            info(f"Could not check Config: {e}")


def main():
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print("=" * 48)
    print("  Control Tower Health Check")
    print(f"  Home Region: {CT_HOME_REGION}")
    print(f"  Date: {now}")
    print("=" * 48)

    ct_client = boto3.client("controltower", region_name=CT_HOME_REGION)
    org_client = boto3.client("organizations", region_name=CT_HOME_REGION)

    lz_arn, lz_governed = check_landing_zone(ct_client)
    check_landing_zone_operations(ct_client)
    check_enabled_controls(ct_client)
    root_id, ous = check_organization(org_client)
    check_accounts(org_client)
    check_account_enrollment(
        ct_client, org_client, root_id, ous, lz_governed
    )
    check_security_hub_all_regions()
    check_cloudtrail(CT_HOME_REGION)
    check_config_compliance()

    print("\n" + "=" * 48)
    print("  Health check complete.")
    print("=" * 48)


if __name__ == "__main__":
    main()