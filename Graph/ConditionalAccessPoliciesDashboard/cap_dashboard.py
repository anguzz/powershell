import re
from itertools import combinations
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------
DEFAULT_CSV_PATH = "ConditionalAccessPolicies_Demo.csv"
ALL = "__ALL__"
NONE = "__NONE__"

RESOURCE_FIELDS = {
    "Applications": (
        "conditions.applications.includeApplications",
        "conditions.applications.excludeApplications",
    ),
    "Users": (
        "conditions.users.includeUsers",
        "conditions.users.excludeUsers",
    ),
    "Groups": (
        "conditions.users.includeGroups",
        "conditions.users.excludeGroups",
    ),
    "Roles": (
        "conditions.users.includeRoles",
        "conditions.users.excludeRoles",
    ),
    "Locations": (
        "conditions.locations.includeLocations",
        "conditions.locations.excludeLocations",
    ),
    "Platforms": (
        "conditions.platforms.includePlatforms",
        "conditions.platforms.excludePlatforms",
    ),
}

CONDITION_FIELDS = [
    "conditions.clientAppTypes",
    "conditions.signInRiskLevels",
    "conditions.userRiskLevels",
    "conditions.servicePrincipalRiskLevels",
    "conditions.insiderRiskLevels",
    "conditions.authenticationFlows.transferMethods",
    "conditions.devices.deviceFilter.mode",
    "conditions.devices.deviceFilter.rule",
    "conditions.applications.includeUserActions",
    "conditions.applications.includeAuthenticationContextClassReferences",
]

CONTROL_FIELDS = [
    "grantControls.builtInControls",
    "grantControls.operator",
    "grantControls.authenticationStrength.id",
    "grantControls.authenticationStrength.displayName",
    "sessionControls.cloudAppSecurity.cloudAppSecurityType",
    "sessionControls.cloudAppSecurity.isEnabled",
    "sessionControls.persistentBrowser.mode",
    "sessionControls.persistentBrowser.isEnabled",
    "sessionControls.signInFrequency.frequencyInterval",
    "sessionControls.signInFrequency.type",
    "sessionControls.signInFrequency.value",
    "sessionControls.signInFrequency.isEnabled",
]

# ---------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------
def safe_text(value):
    if pd.isna(value):
        return ""
    return str(value).strip()


def split_values(value):
    """Split Graph export multi-value cells while preserving names and IDs."""
    text = safe_text(value)
    if not text:
        return set()
    values = {v.strip() for v in text.split(";") if v.strip()}
    return values


def canonical_token(value):
    """Prefer the GUID in parentheses, otherwise use normalized text."""
    value = safe_text(value)
    match = re.search(r"\(([0-9a-fA-F-]{36})\)\s*$", value)
    if match:
        return match.group(1).lower()
    return value.lower()


def canonical_set(value):
    return {canonical_token(v) for v in split_values(value)}


def display_set(value):
    values = sorted(split_values(value), key=str.lower)
    return "; ".join(values)


def normalize_scalar(value):
    return safe_text(value).lower()


def is_all(values):
    return any(v.lower() == "all" for v in values)


def is_none(values):
    return any(v.lower() == "none" for v in values)


def jaccard(a, b):
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def coverage_similarity(a, b):
    """Similarity for includes. 'All' contains a specific set but is not identical to it."""
    a = set(a)
    b = set(b)
    if is_none(a) or is_none(b):
        return 1.0 if a == b else 0.0
    if is_all(a) and is_all(b):
        return 1.0
    if is_all(a) or is_all(b):
        return 0.65
    return jaccard(a, b)


def scalar_similarity(a, b):
    a, b = normalize_scalar(a), normalize_scalar(b)
    if not a and not b:
        return 1.0
    return 1.0 if a == b else 0.0


def control_family(row):
    controls = canonical_set(row.get("grantControls.builtInControls", ""))
    strength = normalize_scalar(row.get("grantControls.authenticationStrength.displayName", ""))
    cloud = normalize_scalar(row.get("sessionControls.cloudAppSecurity.cloudAppSecurityType", ""))
    parts = sorted(controls)
    if strength:
        parts.append(f"auth:{strength}")
    if cloud:
        parts.append(f"session:{cloud}")
    return " + ".join(parts) if parts else "No explicit grant control"


def target_summary(row):
    parts = []
    for label, (inc, exc) in RESOURCE_FIELDS.items():
        included = display_set(row.get(inc, ""))
        excluded = display_set(row.get(exc, ""))
        if included:
            parts.append(f"{label}: {included}")
        if excluded:
            parts.append(f"Except {label}: {excluded}")
    return " | ".join(parts)


def compact_list(value, limit=3):
    vals = sorted(split_values(value), key=str.lower)
    if len(vals) <= limit:
        return "; ".join(vals)
    return "; ".join(vals[:limit]) + f"; +{len(vals)-limit} more"


@st.cache_data
def load_data(source):
    df = pd.read_csv(source, dtype=str, encoding="utf-8").fillna("")
    required = ["displayName", "id", "state"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns: {', '.join(missing)}")

    for col in ["createdDateTime", "modifiedDateTime", "deletedDateTime"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce", utc=True)

    df["PolicyType"] = np.where(df.get("templateId", "").astype(str).str.strip().ne(""), "Microsoft-managed", "Custom")
    df["ControlFamily"] = df.apply(control_family, axis=1)
    df["TargetSummary"] = df.apply(target_summary, axis=1)
    df["IsStagingNamed"] = df["displayName"].str.match(r"(?i)^\s*stg\b|^\s*test\b", na=False)
    df["HasUnresolvedObject"] = df.astype(str).apply(lambda s: s.str.contains(r"\[Unresolved\]", case=False, regex=True)).any(axis=1)

    resource_count = pd.Series(0, index=df.index, dtype=int)
    for _, (inc, exc) in RESOURCE_FIELDS.items():
        if inc in df:
            resource_count += df[inc].map(lambda x: len(split_values(x)))
        if exc in df:
            resource_count += df[exc].map(lambda x: len(split_values(x)))
    df["ReferencedObjectCount"] = resource_count
    return df


def policy_signature(row, include_state=False):
    fields = []
    for inc, exc in RESOURCE_FIELDS.values():
        fields.extend([inc, exc])
    fields += CONDITION_FIELDS + CONTROL_FIELDS
    if include_state:
        fields.append("state")
    signature = []
    for field in fields:
        value = row.get(field, "")
        if field.startswith("conditions.") or field == "grantControls.builtInControls":
            signature.append((field, tuple(sorted(canonical_set(value)))))
        else:
            signature.append((field, normalize_scalar(value)))
    return tuple(signature)


def dimensions_for_row(row):
    result = {}
    for label, (inc, exc) in RESOURCE_FIELDS.items():
        result[label] = {
            "include": canonical_set(row.get(inc, "")),
            "exclude": canonical_set(row.get(exc, "")),
        }
    return result


def pair_analysis(df):
    rows = []
    records = list(df.to_dict("records"))
    for a, b in combinations(records, 2):
        ad = dimensions_for_row(a)
        bd = dimensions_for_row(b)

        target_scores = []
        same_dimensions = []
        overlapping_dimensions = []
        for label in RESOURCE_FIELDS:
            a_include = ad[label]["include"]
            b_include = bd[label]["include"]
            a_exclude = ad[label]["exclude"]
            b_exclude = bd[label]["exclude"]

            # Ignore resource dimensions that neither policy uses. This prevents
            # blank-vs-blank fields from making unrelated policies look similar.
            if not (a_include or b_include or a_exclude or b_exclude):
                continue

            inc_score = coverage_similarity(a_include, b_include)

            # Exclusions only contribute when at least one policy uses them.
            if a_exclude or b_exclude:
                exc_score = jaccard(a_exclude, b_exclude)
                score = 0.75 * inc_score + 0.25 * exc_score
            else:
                score = inc_score

            target_scores.append(score)
            if score == 1:
                same_dimensions.append(label)
            elif score > 0:
                overlapping_dimensions.append(label)

        condition_scores = []
        for field in CONDITION_FIELDS:
            a_values = canonical_set(a.get(field, ""))
            b_values = canonical_set(b.get(field, ""))
            if not a_values and not b_values:
                continue
            condition_scores.append(jaccard(a_values, b_values))

        control_scores = []
        for field in CONTROL_FIELDS:
            a_value = a.get(field, "")
            b_value = b.get(field, "")
            if not safe_text(a_value) and not safe_text(b_value):
                continue
            control_scores.append(scalar_similarity(a_value, b_value))

        target_similarity = float(np.mean(target_scores)) if target_scores else 0.0
        condition_similarity = float(np.mean(condition_scores)) if condition_scores else 0.0
        control_similarity = float(np.mean(control_scores)) if control_scores else 0.0
        overall = 100 * (0.55 * target_similarity + 0.25 * condition_similarity + 0.20 * control_similarity)

        exact_logic = policy_signature(a) == policy_signature(b)
        controls_same = control_similarity == 1.0
        state_same = normalize_scalar(a.get("state")) == normalize_scalar(b.get("state"))

        control_a = canonical_set(a.get("grantControls.builtInControls", ""))
        control_b = canonical_set(b.get("grantControls.builtInControls", ""))
        block_conflict = ("block" in control_a) != ("block" in control_b)

        if exact_logic:
            classification = "Exact duplicate logic"
            priority = "High"
            recommendation = "Keep the intended policy, validate sign-in impact, then disable and remove the duplicate."
        elif overall >= 85 and controls_same:
            classification = "Near duplicate"
            priority = "High"
            recommendation = "Compare the small targeting differences. Consider merging targets into one policy."
        elif overall >= 70 and controls_same:
            classification = "Strong consolidation candidate"
            priority = "Medium"
            recommendation = "Review whether separate populations or apps still need separate policies."
        elif target_similarity >= 0.75 and block_conflict:
            classification = "Overlapping controls"
            priority = "High"
            recommendation = "Review precedence and effective access. A block policy overlaps a non-block policy."
        elif target_similarity >= 0.70:
            classification = "Target overlap"
            priority = "Medium"
            recommendation = "Policies target similar resources but differ in conditions or controls. Validate intentional layering."
        elif overall >= 50:
            classification = "Partial overlap"
            priority = "Low"
            recommendation = "Low-priority review. Shared exclusions, users, apps, or locations may be reusable."
        else:
            classification = "Low similarity"
            priority = "Informational"
            recommendation = "No immediate consolidation action based on configuration similarity."

        rows.append({
            "Policy A": a.get("displayName", ""),
            "Policy B": b.get("displayName", ""),
            "Policy A ID": a.get("id", ""),
            "Policy B ID": b.get("id", ""),
            "State A": a.get("state", ""),
            "State B": b.get("state", ""),
            "Overall Similarity": round(overall, 1),
            "Target Similarity": round(target_similarity * 100, 1),
            "Condition Similarity": round(condition_similarity * 100, 1),
            "Control Similarity": round(control_similarity * 100, 1),
            "Classification": classification,
            "Priority": priority,
            "Same Dimensions": ", ".join(same_dimensions),
            "Partially Overlapping Dimensions": ", ".join(overlapping_dimensions),
            "Same State": state_same,
            "Same Controls": controls_same,
            "Block/Non-block Conflict": block_conflict,
            "Recommendation": recommendation,
        })
    return pd.DataFrame(rows).sort_values(
        ["Overall Similarity", "Target Similarity"], ascending=False
    )


def policy_rollup(df, pairs):
    result = df[["displayName", "id", "state", "PolicyType", "ControlFamily", "ReferencedObjectCount", "modifiedDateTime", "IsStagingNamed", "HasUnresolvedObject"]].copy()
    counts = []
    best = []
    top_partner = []
    for _, row in result.iterrows():
        subset = pairs[(pairs["Policy A ID"] == row["id"]) | (pairs["Policy B ID"] == row["id"])]
        review = subset[subset["Priority"].isin(["High", "Medium"])]
        counts.append(len(review))
        if subset.empty:
            best.append(0.0)
            top_partner.append("")
        else:
            top = subset.iloc[0]
            best.append(top["Overall Similarity"])
            top_partner.append(top["Policy B"] if top["Policy A ID"] == row["id"] else top["Policy A"])
    result["ReviewPairCount"] = counts
    result["HighestSimilarity"] = best
    result["TopMatch"] = top_partner

    result["ReviewReason"] = ""
    result.loc[result["state"] == "disabled", "ReviewReason"] += "Disabled policy; "
    result.loc[result["state"] == "enabledForReportingButNotEnforced", "ReviewReason"] += "Report-only policy; "
    result.loc[result["IsStagingNamed"], "ReviewReason"] += "Staging/test naming; "
    result.loc[result["HasUnresolvedObject"], "ReviewReason"] += "Unresolved object reference; "
    result.loc[result["ReviewPairCount"] > 0, "ReviewReason"] += "Overlapping configuration; "
    result["ReviewReason"] = result["ReviewReason"].str.rstrip("; ")
    result["NeedsReview"] = result["ReviewReason"].ne("")
    return result.sort_values(["NeedsReview", "HighestSimilarity"], ascending=False)


def resource_inventory(df):
    rows = []
    for _, policy in df.iterrows():
        for dimension, (inc, exc) in RESOURCE_FIELDS.items():
            for direction, col in [("Include", inc), ("Exclude", exc)]:
                for raw in split_values(policy.get(col, "")):
                    rows.append({
                        "Resource": raw,
                        "ResourceKey": canonical_token(raw),
                        "Dimension": dimension,
                        "Direction": direction,
                        "Policy": policy["displayName"],
                        "Policy ID": policy["id"],
                        "State": policy["state"],
                    })
    resources = pd.DataFrame(rows)
    if resources.empty:
        return resources, pd.DataFrame()
    summary = resources.groupby(["Resource", "ResourceKey", "Dimension", "Direction"], as_index=False).agg(
        PolicyCount=("Policy ID", "nunique"),
        Policies=("Policy", lambda s: "; ".join(sorted(set(s), key=str.lower))),
        States=("State", lambda s: "; ".join(sorted(set(s), key=str.lower))),
    )
    return resources, summary.sort_values(["PolicyCount", "Resource"], ascending=[False, True])


def overlap_heatmap(df, pairs):
    # The matrix intentionally shows target overlap only. Conditions and controls
    # remain available in the candidate table and side-by-side comparison.
    names = df["displayName"].tolist()
    matrix = pd.DataFrame(np.eye(len(names)) * 100, index=names, columns=names)
    for _, row in pairs.iterrows():
        matrix.loc[row["Policy A"], row["Policy B"]] = row["Target Similarity"]
        matrix.loc[row["Policy B"], row["Policy A"]] = row["Target Similarity"]
    fig = px.imshow(
        matrix,
        zmin=0,
        zmax=100,
        color_continuous_scale="Blues",
        labels={"color": "Target similarity"},
        aspect="auto",
        title="Policy target similarity matrix",
    )
    fig.update_layout(height=max(650, len(names) * 22), xaxis_tickangle=-45)
    return fig


def policy_network(df, pairs, threshold):
    edges = pairs[pairs["Overall Similarity"] >= threshold].copy()
    if edges.empty:
        return None
    nodes = sorted(set(edges["Policy A"]) | set(edges["Policy B"]))
    n = len(nodes)
    angles = np.linspace(0, 2 * np.pi, n, endpoint=False)
    pos = {node: (np.cos(a), np.sin(a)) for node, a in zip(nodes, angles)}

    edge_x, edge_y = [], []
    for _, edge in edges.iterrows():
        x0, y0 = pos[edge["Policy A"]]
        x1, y1 = pos[edge["Policy B"]]
        edge_x += [x0, x1, None]
        edge_y += [y0, y1, None]

    states = df.set_index("displayName")["state"].to_dict()
    colors = {
        "enabled": "#d62728",
        "enabledForReportingButNotEnforced": "#ffbf00",
        "disabled": "#7f7f7f",
    }
    node_colors = [colors.get(states.get(n, ""), "#1f77b4") for n in nodes]
    degrees = {node: 0 for node in nodes}
    for _, edge in edges.iterrows():
        degrees[edge["Policy A"]] += 1
        degrees[edge["Policy B"]] += 1

    fig = go.Figure()
    fig.add_trace(go.Scatter(x=edge_x, y=edge_y, mode="lines", line=dict(width=1, color="#aab2bd"), hoverinfo="none"))
    fig.add_trace(go.Scatter(
        x=[pos[n][0] for n in nodes],
        y=[pos[n][1] for n in nodes],
        mode="markers+text",
        text=[n if len(n) <= 38 else n[:35] + "..." for n in nodes],
        textposition="top center",
        marker=dict(size=[12 + min(degrees[n] * 3, 24) for n in nodes], color=node_colors, line=dict(width=1, color="white")),
        customdata=[[n, states.get(n, ""), degrees[n]] for n in nodes],
        hovertemplate="%{customdata[0]}<br>State: %{customdata[1]}<br>Overlap links: %{customdata[2]}<extra></extra>",
    ))
    fig.update_layout(title=f"Overlap network at {threshold}% similarity", showlegend=False, height=700, xaxis=dict(visible=False), yaxis=dict(visible=False))
    return fig


def csv_bytes(df):
    return df.to_csv(index=False).encode("utf-8")

# ---------------------------------------------------------
# App
# ---------------------------------------------------------
st.set_page_config(page_title="Conditional Access Consolidation Dashboard", layout="wide")
st.title("Conditional Access Consolidation Dashboard")
st.caption("Configuration-based review of policy targets, controls, exclusions, and possible consolidation candidates.")

with st.sidebar:
    st.header("Data")
    uploaded = st.file_uploader("Conditional Access CSV", type=["csv"])
    source = uploaded if uploaded is not None else DEFAULT_CSV_PATH

try:
    df = load_data(source)
except Exception as exc:
    st.error(f"Could not load the CSV: {exc}")
    st.stop()

pairs = pair_analysis(df)
rollup = policy_rollup(df, pairs)
resources, resource_summary = resource_inventory(df)

with st.sidebar:
    st.header("Filters")
    states = sorted(df["state"].dropna().unique().tolist())
    state_sel = st.multiselect("Policy state", states, default=states)
    types = sorted(df["PolicyType"].unique().tolist())
    type_sel = st.multiselect("Policy type", types, default=types)
    search = st.text_input("Policy search")
    min_similarity = st.slider("Minimum pair similarity", 0, 100, 60, 5)
    pair_priorities = st.multiselect("Pair priority", ["High", "Medium", "Low", "Informational"], default=["High", "Medium"])
    include_disabled_pairs = st.checkbox("Include pairs where both policies are disabled", value=False)

mask = df["state"].isin(state_sel) & df["PolicyType"].isin(type_sel)
if search:
    mask &= df["displayName"].str.contains(search, case=False, na=False)
df_view = df[mask].copy()
visible_ids = set(df_view["id"])

pairs_view = pairs[
    pairs["Policy A ID"].isin(visible_ids)
    & pairs["Policy B ID"].isin(visible_ids)
    & (pairs["Overall Similarity"] >= min_similarity)
    & pairs["Priority"].isin(pair_priorities)
].copy()
if not include_disabled_pairs:
    pairs_view = pairs_view[~((pairs_view["State A"] == "disabled") & (pairs_view["State B"] == "disabled"))]

rollup_view = rollup[rollup["id"].isin(visible_ids)].copy()

c1, c2, c3, c4, c5, c6 = st.columns(6)
c1.metric("Policies", f"{len(df_view):,}")
c2.metric("Enabled", f"{(df_view['state'] == 'enabled').sum():,}")
c3.metric("Report-only", f"{(df_view['state'] == 'enabledForReportingButNotEnforced').sum():,}")
c4.metric("Disabled", f"{(df_view['state'] == 'disabled').sum():,}")
c5.metric("High/medium pairs", f"{len(pairs_view):,}")
c6.metric("Referenced objects", f"{df_view['ReferencedObjectCount'].sum():,}")

st.warning("Important: similarity means the exported configurations look alike. It does not prove identical effective coverage because group membership, role assignment, nested groups, named-location definitions, app behavior, and sign-in telemetry are not contained in this CSV.")

summary_tab, overlap_tab, matrix_tab, resource_tab, policy_tab, export_tab = st.tabs([
    "Overview", "Consolidation candidates", "Matrix and network", "Resource reuse", "Policy explorer", "Exports"
])

with summary_tab:
    left, right = st.columns(2)
    state_counts = df_view["state"].value_counts().reset_index()
    state_counts.columns = ["State", "Count"]
    left.plotly_chart(px.bar(state_counts, x="State", y="Count", color="State", title="Policies by state"), use_container_width=True)

    control_counts = df_view["ControlFamily"].value_counts().head(15).reset_index()
    control_counts.columns = ["Control family", "Count"]
    right.plotly_chart(px.bar(control_counts, x="Count", y="Control family", orientation="h", title="Top control patterns"), use_container_width=True)

    left2, right2 = st.columns(2)
    if not pairs_view.empty:
        class_counts = pairs_view["Classification"].value_counts().reset_index()
        class_counts.columns = ["Classification", "Count"]
        left2.plotly_chart(px.bar(class_counts, x="Classification", y="Count", color="Classification", title="Candidate pair types"), use_container_width=True)
    else:
        left2.info("No pairs match the current filters.")

    review_counts = rollup_view["ReviewReason"].replace("", "No automatic flag").value_counts().head(12).reset_index()
    review_counts.columns = ["Review reason", "Count"]
    right2.plotly_chart(px.bar(review_counts, x="Count", y="Review reason", orientation="h", title="Automatic review signals"), use_container_width=True)

    st.subheader("Highest-priority policies")
    st.dataframe(rollup_view.head(25), use_container_width=True, height=520)

with overlap_tab:
    st.subheader("Candidate policy pairs")
    st.caption("Sort by similarity, then verify scope and sign-in impact before changing enforcement.")
    if pairs_view.empty:
        st.info("No candidate pairs match the current filters. Lower the similarity threshold or include more priorities.")
    else:
        selected_classes = st.multiselect("Classification", sorted(pairs_view["Classification"].unique()), default=sorted(pairs_view["Classification"].unique()))
        pair_table = pairs_view[pairs_view["Classification"].isin(selected_classes)].copy()
        st.dataframe(pair_table, use_container_width=True, height=640)

        st.subheader("Compare two policies")
        names = sorted(df_view["displayName"].tolist())
        ca, cb = st.columns(2)
        name_a = ca.selectbox("Policy A", names, index=0 if names else None)
        default_b = 1 if len(names) > 1 else 0
        name_b = cb.selectbox("Policy B", names, index=default_b if names else None)
        if names and name_a and name_b:
            arow = df_view[df_view["displayName"] == name_a].iloc[0]
            brow = df_view[df_view["displayName"] == name_b].iloc[0]
            compare_rows = []
            compare_fields = ["state"] + [v for pair in RESOURCE_FIELDS.values() for v in pair] + CONDITION_FIELDS + CONTROL_FIELDS
            for field in compare_fields:
                av = display_set(arow.get(field, "")) if field.startswith("conditions.") or field == "grantControls.builtInControls" else safe_text(arow.get(field, ""))
                bv = display_set(brow.get(field, "")) if field.startswith("conditions.") or field == "grantControls.builtInControls" else safe_text(brow.get(field, ""))
                compare_rows.append({"Field": field, "Policy A": av, "Policy B": bv, "Same": av.lower() == bv.lower()})
            st.dataframe(pd.DataFrame(compare_rows), use_container_width=True, height=600)

with matrix_tab:
    if len(df_view) > 1:
        st.plotly_chart(overlap_heatmap(df_view, pairs), use_container_width=True)
        network_threshold = st.slider("Network similarity threshold", 50, 100, 75, 5)
        network = policy_network(df_view, pairs, network_threshold)
        if network:
            st.plotly_chart(network, use_container_width=True)
        else:
            st.info("No network edges at this threshold.")
    else:
        st.info("At least two policies are needed for comparison.")

with resource_tab:
    st.subheader("Resources reused across policies")
    if resource_summary.empty:
        st.info("No reusable resource references were parsed.")
    else:
        dim_sel = st.multiselect("Resource dimension", sorted(resource_summary["Dimension"].unique()), default=sorted(resource_summary["Dimension"].unique()))
        dir_sel = st.multiselect("Direction", ["Include", "Exclude"], default=["Include", "Exclude"])
        min_policy_count = st.number_input("Minimum policy count", min_value=1, value=2, step=1)
        resource_view = resource_summary[
            resource_summary["Dimension"].isin(dim_sel)
            & resource_summary["Direction"].isin(dir_sel)
            & (resource_summary["PolicyCount"] >= min_policy_count)
        ]
        fig = px.bar(resource_view.head(30), x="PolicyCount", y="Resource", color="Dimension", orientation="h", title="Most reused targets and exclusions")
        st.plotly_chart(fig, use_container_width=True)
        st.dataframe(resource_view, use_container_width=True, height=620)

with policy_tab:
    st.subheader("Policy drill-down")
    names = sorted(df_view["displayName"].tolist())
    selected = st.selectbox("Policy", names)
    if selected:
        row = df_view[df_view["displayName"] == selected].iloc[0]
        a, b, c = st.columns(3)
        a.metric("State", row["state"])
        b.metric("Control", row["ControlFamily"])
        c.metric("Referenced objects", int(row["ReferencedObjectCount"]))
        st.write(row["TargetSummary"] or "No target summary available.")
        detail = pd.DataFrame({"Field": row.index, "Value": [safe_text(v) for v in row.values]})
        detail = detail[detail["Value"].ne("")]
        st.dataframe(detail, use_container_width=True, height=700)

with export_tab:
    st.subheader("Download review outputs")
    st.download_button("Download consolidation candidates", csv_bytes(pairs_view), "CAP-Consolidation-Candidates.csv", "text/csv")
    st.download_button("Download policy review rollup", csv_bytes(rollup_view), "CAP-Policy-Review-Rollup.csv", "text/csv")
    st.download_button("Download resource reuse inventory", csv_bytes(resource_summary), "CAP-Resource-Reuse.csv", "text/csv")
    st.download_button("Download filtered policies", csv_bytes(df_view), "CAP-Policies-Filtered.csv", "text/csv")

    st.markdown("""
### Suggested review order
1. Exact duplicate logic and near duplicates.
2. Enabled policies with overlapping block and non-block controls.
3. Report-only and staging policies with no current testing purpose.
4. Disabled policies after confirming they have no rollback or audit requirement.
5. Shared app, group, location, and exclusion lists that can be moved into a smaller number of baseline policies.

### Before consolidation
- Use Conditional Access What If and sign-in logs.
- Resolve group membership, nested membership, named locations, role assignments, and application ownership.
- Move the replacement policy to report-only first.
- Compare old and replacement results before disabling the originals.
""")
