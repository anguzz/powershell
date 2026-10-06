# Conditional Access Consolidation Dashboard

This project helps visualize, analyze, and consolidate Microsoft Entra Conditional Access policies.

The included PowerShell export script retrieves full Conditional Access policy configurations from Microsoft Graph, resolves referenced objects to friendly names, and exports a dashboard-ready CSV.

The Streamlit dashboard then helps identify:

- Duplicate and near-duplicate policies
- Policy overlap
- Shared applications, groups, locations, and roles
- Consolidation opportunities
- Report-only and disabled policies
- Resource reuse across the environment

## Run

0. Run `Export-ConditionalAccessPolicies.ps1` with necessary graph permissions. This grabs all condtiaonl access policies objects, and resolves object refereences it points to as well. 
1. Put `ConditionalAccessPolicies_Full.csv` in the same folder as `cap_dashboard.py`.
2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Start the dashboard:

```bash
streamlit run cap_dashboard.py
```

You can also upload a newer export from the dashboard sidebar.

## Limitations

The score compares exported policy configuration. It does not prove two policies have the same effective coverage because the CSV does not contain current group membership, nested groups, role assignments, named-location definitions, application behavior, or sign-in telemetry. Treat every recommendation as a review lead, not an automatic deletion decision.

## Sample Dataset

A synthetic sample dataset is included for demonstration purposes:

- ConditionalAccessPolicies_Sample.csv

The sample file contains fictional policies, groups, applications, locations, and roles.

No production or customer data is included.


## Important

Similarity scores are based on exported policy configuration and targeting data.

The dashboard does not evaluate:

- Current group membership
- Nested groups
- Dynamic group rules
- Effective role assignments
- Named location contents
- Sign-in logs
- Conditional Access "What If" results

Always validate findings before modifying production policies.