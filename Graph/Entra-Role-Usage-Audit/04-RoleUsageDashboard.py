"""Entra role usage dashboard.

Visualizes RoleUsageAnalysis.csv (output of 03-Merge-RoleUsage.ps1) so role
assignments can be reviewed against observed sign-in activity.

Run:
    python -m streamlit run 04-RoleUsageDashboard.py --server.address 127.0.0.1
"""

from pathlib import Path
import re

import pandas as pd
import streamlit as st

st.set_page_config(page_title="Entra Role Usage Audit", page_icon="🔎", layout="wide")

DEFAULT_FILE = Path(__file__).with_name("RoleUsageAnalysis.csv")
SAMPLE_FILE = Path(__file__).parent / "sample-data" / "RoleUsageAnalysis.sample.csv"


# ------------------------------------------------------------
# Data loading
# ------------------------------------------------------------

@st.cache_data(show_spinner=False)
def load_csv(source):
    df = pd.read_csv(source, dtype=str, engine="python", on_bad_lines="warn")
    df.columns = [str(c).strip() for c in df.columns]
    return prepare_data(df)


def clean_text(series, fallback="Unknown"):
    return (
        series.fillna("")
        .astype(str)
        .str.strip()
        .replace({"": fallback, "nan": fallback, "None": fallback})
    )


def to_bool(series):
    return series.fillna("").astype(str).str.strip().str.lower().isin(["true", "1", "yes"])


def split_values(value):
    if pd.isna(value) or not str(value).strip():
        return []
    return [item.strip() for item in str(value).split(";") if item.strip()]


def prepare_data(df):
    required = ["Role", "DisplayName", "UserPrincipalName"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns: {', '.join(missing)}")

    text_columns = [
        "Role", "RoleType", "AssignmentState", "AssignmentType", "AssignedGroup",
        "Scope", "PrincipalType", "DisplayName", "UserPrincipalName", "JobTitle",
        "Department", "Manager", "UserType",
    ]
    for column in text_columns:
        df[column] = clean_text(df[column]) if column in df.columns else "Unknown"

    # Non-user principals (service principals, devices) have no UPN; key them by display name.
    df["PrincipalKey"] = df["UserPrincipalName"].where(
        df["UserPrincipalName"].ne("Unknown"), df["DisplayName"]
    ).str.lower()

    for column in ["ResourceCount", "ApplicationCount", "TotalSignIns", "ActiveDays"]:
        source = df[column] if column in df.columns else pd.Series(0, index=df.index)
        df[column] = pd.to_numeric(source, errors="coerce").fillna(0).astype("int64")

    df["DaysSinceLastSeen"] = pd.to_numeric(df.get("DaysSinceLastSeen"), errors="coerce")

    activity_col = next(
        (c for c in ["HasObservedActivity", "HasObservedAuthentication"] if c in df.columns), None
    )
    df["HasObservedActivity"] = to_bool(df[activity_col]) if activity_col else df["TotalSignIns"].gt(0)
    df["AccountEnabledFlag"] = to_bool(df["AccountEnabled"]) if "AccountEnabled" in df.columns else True
    df["LastSeenDate"] = pd.to_datetime(df.get("LastSeen"), errors="coerce")

    for column in ["Resources", "Applications", "ResourceUsage"]:
        df[column] = df[column].fillna("").astype(str) if column in df.columns else ""

    return df


def classify_accounts(df, admin_prefixes, service_pattern):
    df = df.copy()
    upn = df["UserPrincipalName"]
    df["AccountClass"] = "Standard"

    prefixes = tuple(p.strip().lower() for p in admin_prefixes.split(",") if p.strip())
    if prefixes:
        df.loc[upn.str.lower().str.startswith(prefixes, na=False), "AccountClass"] = "Admin"

    df.loc[upn.str.contains("#EXT#", case=False, na=False), "AccountClass"] = "Guest"

    if service_pattern.strip():
        try:
            is_service = upn.str.contains(service_pattern, case=False, na=False, regex=True)
        except re.error:
            st.sidebar.warning("Service account pattern is not a valid regex.")
            is_service = pd.Series(False, index=df.index)
        df.loc[is_service, "AccountClass"] = "Service"

    df.loc[df["PrincipalType"].str.lower().eq("serviceprincipal"), "AccountClass"] = "Service principal"
    return df


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

def multiselect_filter(frame, column, label):
    options = sorted(frame[column].dropna().astype(str).unique().tolist())
    if len(options) <= 1:
        return frame
    selected = st.sidebar.multiselect(label, options)
    return frame[frame[column].isin(selected)] if selected else frame


def explode_dimension(frame, source_column, output_column):
    subset = frame[["PrincipalKey", "TotalSignIns", source_column]].copy()
    subset[output_column] = subset[source_column].apply(split_values)
    subset = subset.explode(output_column)
    return subset[subset[output_column].notna() & subset[output_column].ne("")]


def count_principals_by_value(frame, source_column, output_column):
    expanded = explode_dimension(frame, source_column, output_column)
    if expanded.empty:
        return pd.DataFrame(columns=[output_column, "Principals"])
    return (
        expanded.groupby(output_column, as_index=False)["PrincipalKey"]
        .nunique()
        .rename(columns={"PrincipalKey": "Principals"})
        .sort_values("Principals", ascending=False)
    )


def active_count(frame):
    return lambda s: s[frame.loc[s.index, "HasObservedActivity"]].nunique()


def fmt(value):
    return f"{int(value):,}"


# ------------------------------------------------------------
# Load
# ------------------------------------------------------------

st.title("Entra Role Usage Audit")
st.caption(
    "Directory role assignments enriched with observed sign-in activity. "
    "Sign-ins show which services a principal uses, not which role permissions were exercised."
)

uploaded = st.sidebar.file_uploader("Upload RoleUsageAnalysis.csv", type=["csv"])
if uploaded is not None:
    source = uploaded
elif DEFAULT_FILE.exists():
    source = DEFAULT_FILE
elif SAMPLE_FILE.exists():
    source = SAMPLE_FILE
    st.info("Showing sample data. Upload your own RoleUsageAnalysis.csv from the sidebar.")
else:
    st.info("Upload RoleUsageAnalysis.csv from the sidebar to begin.")
    st.stop()

try:
    data = load_csv(source)
except Exception as exc:
    st.error(f"Could not load the CSV: {exc}")
    st.stop()

with st.sidebar.expander("Account classification"):
    admin_prefixes = st.text_input("Admin account prefixes (comma separated)", "admin-,adm-,a-")
    service_pattern = st.text_input("Service account UPN pattern (regex)", r"svc|service")
    stale_days = st.number_input("Treat as stale after (days without sign-in)", 1, 365, 30)

data = classify_accounts(data, admin_prefixes, service_pattern)

# ------------------------------------------------------------
# Filters
# ------------------------------------------------------------

st.sidebar.header("Filters")
filtered = data
filtered = multiselect_filter(filtered, "Role", "Role")
filtered = multiselect_filter(filtered, "RoleType", "Role type")
filtered = multiselect_filter(filtered, "AssignmentState", "Assignment state")
filtered = multiselect_filter(filtered, "AssignmentType", "Assignment type")
filtered = multiselect_filter(filtered, "AssignedGroup", "Assigned group")
filtered = multiselect_filter(filtered, "PrincipalType", "Principal type")
filtered = multiselect_filter(filtered, "AccountClass", "Account class")
filtered = multiselect_filter(filtered, "Department", "Department")
filtered = multiselect_filter(filtered, "JobTitle", "Job title")

activity_filter = st.sidebar.radio("Observed activity", ["All", "Observed", "Not observed"])
if activity_filter == "Observed":
    filtered = filtered[filtered["HasObservedActivity"]]
elif activity_filter == "Not observed":
    filtered = filtered[~filtered["HasObservedActivity"]]

enabled_filter = st.sidebar.radio("Account status", ["All", "Enabled", "Disabled"])
if enabled_filter == "Enabled":
    filtered = filtered[filtered["AccountEnabledFlag"]]
elif enabled_filter == "Disabled":
    filtered = filtered[~filtered["AccountEnabledFlag"]]

search = st.sidebar.text_input("Search name, UPN, resource, or application")
if search.strip():
    escaped = re.escape(search.strip())
    mask = pd.Series(False, index=filtered.index)
    for col in ["DisplayName", "UserPrincipalName", "Resources", "Applications"]:
        mask |= filtered[col].str.contains(escaped, case=False, na=False, regex=True)
    filtered = filtered[mask]

st.sidebar.caption(f"Showing {len(filtered):,} of {len(data):,} assignment rows")

# ------------------------------------------------------------
# Metrics
# ------------------------------------------------------------

unique_principals = filtered["PrincipalKey"].nunique()
observed = filtered.loc[filtered["HasObservedActivity"], "PrincipalKey"].nunique()
resources = count_principals_by_value(filtered, "Resources", "Resource")
applications = count_principals_by_value(filtered, "Applications", "Application")

# TotalSignIns repeats for principals holding several roles; count each principal once.
per_principal = filtered.sort_values("TotalSignIns", ascending=False).drop_duplicates("PrincipalKey")

cols = st.columns(6)
cols[0].metric("Assignment rows", fmt(len(filtered)))
cols[1].metric("Unique principals", fmt(unique_principals))
cols[2].metric("With activity", fmt(observed))
cols[3].metric("Without activity", fmt(max(unique_principals - observed, 0)))
cols[4].metric("Distinct resources", fmt(len(resources)))
cols[5].metric("Sign-in events", fmt(per_principal["TotalSignIns"].sum()))

overview_tab, review_tab, functions_tab, resources_tab, principals_tab, data_tab = st.tabs(
    ["Overview", "Review candidates", "Functions", "Resources & apps", "Principals", "Data"]
)

# ------------------------------------------------------------
# Overview
# ------------------------------------------------------------

with overview_tab:
    left, right = st.columns(2)
    role_summary = (
        filtered.groupby("Role", as_index=False)
        .agg(
            Principals=("PrincipalKey", "nunique"),
            WithActivity=("PrincipalKey", active_count(filtered)),
        )
        .sort_values("Principals", ascending=False)
    )
    role_summary["WithoutActivity"] = role_summary["Principals"] - role_summary["WithActivity"]

    with left:
        st.subheader("Principals by role")
        if role_summary.empty:
            st.info("No records match the filters.")
        else:
            st.bar_chart(role_summary.set_index("Role")[["WithActivity", "WithoutActivity"]], horizontal=True)
            st.dataframe(role_summary, width="stretch", hide_index=True)

    with right:
        st.subheader("Assignment paths")
        paths = (
            filtered.groupby(["AssignmentState", "AssignmentType"], as_index=False)
            .agg(Principals=("PrincipalKey", "nunique"))
        )
        st.dataframe(paths, width="stretch", hide_index=True)

        st.subheader("Account classes")
        classes = (
            filtered.groupby("AccountClass", as_index=False)
            .agg(Principals=("PrincipalKey", "nunique"))
            .sort_values("Principals", ascending=False)
        )
        st.dataframe(classes, width="stretch", hide_index=True)

# ------------------------------------------------------------
# Review candidates
# ------------------------------------------------------------

with review_tab:
    st.subheader("Assignments worth reviewing")
    st.caption(
        "Principals with no observed sign-ins, sign-ins older than the stale threshold, or disabled accounts. "
        "Absence of sign-ins is a signal, not proof the role is unused (e.g. API-only or PIM-activated access)."
    )
    no_activity = ~filtered["HasObservedActivity"]
    stale = filtered["DaysSinceLastSeen"].ge(stale_days)
    disabled = ~filtered["AccountEnabledFlag"]
    candidates = filtered[no_activity | stale | disabled].copy()
    candidates["Reason"] = (
        no_activity.map({True: "No activity; ", False: ""})
        + stale.map({True: "Stale; ", False: ""})
        + disabled.map({True: "Disabled; ", False: ""})
    )[candidates.index].str.rstrip("; ")

    st.dataframe(
        candidates[[
            "Reason", "Role", "AssignmentState", "AssignmentType", "AssignedGroup",
            "DisplayName", "UserPrincipalName", "AccountClass", "Department",
            "JobTitle", "LastSeenDate", "DaysSinceLastSeen",
        ]].sort_values(["Role", "Reason"]),
        width="stretch",
        hide_index=True,
    )

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

with functions_tab:
    st.subheader("Usage by department or job title")
    group_mode = st.radio("Group by", ["Department", "Job title"], horizontal=True)
    group_col = "Department" if group_mode == "Department" else "JobTitle"

    function_summary = (
        filtered.groupby(group_col, as_index=False)
        .agg(
            Principals=("PrincipalKey", "nunique"),
            WithActivity=("PrincipalKey", active_count(filtered)),
            Roles=("Role", lambda s: "; ".join(sorted(set(s)))),
            AverageResources=("ResourceCount", "mean"),
            LatestActivity=("LastSeenDate", "max"),
        )
        .sort_values("Principals", ascending=False)
    )
    function_summary["AverageResources"] = function_summary["AverageResources"].round(1)
    st.dataframe(function_summary, width="stretch", hide_index=True)

    st.subheader(f"Top resources per {group_mode.lower()}")
    exploded = explode_dimension(filtered, "Resources", "Resource")
    if exploded.empty:
        st.info("No resource activity for the selected filters.")
    else:
        exploded[group_col] = filtered.loc[exploded.index, group_col]
        top = (
            exploded.groupby([group_col, "Resource"], as_index=False)
            .agg(Principals=("PrincipalKey", "nunique"))
            .sort_values([group_col, "Principals"], ascending=[True, False])
        )
        top = top[top.groupby(group_col).cumcount() < 10]
        st.dataframe(top, width="stretch", hide_index=True)

# ------------------------------------------------------------
# Resources & apps
# ------------------------------------------------------------

with resources_tab:
    left, right = st.columns(2)
    with left:
        st.subheader("Resources by distinct principals")
        n = st.slider("Resources shown", 5, 30, 15)
        if resources.empty:
            st.info("No resource data.")
        else:
            st.bar_chart(resources.head(n).set_index("Resource")["Principals"], horizontal=True)
            st.dataframe(resources, width="stretch", hide_index=True)
    with right:
        st.subheader("Applications by distinct principals")
        n = st.slider("Applications shown", 5, 30, 15)
        if applications.empty:
            st.info("No application data.")
        else:
            st.bar_chart(applications.head(n).set_index("Application")["Principals"], horizontal=True)
            st.dataframe(applications, width="stretch", hide_index=True)

# ------------------------------------------------------------
# Principals
# ------------------------------------------------------------

with principals_tab:
    st.subheader("Per-principal view")
    principal_summary = (
        filtered.groupby(
            ["DisplayName", "UserPrincipalName", "AccountClass", "Department", "JobTitle"],
            as_index=False,
        )
        .agg(
            Roles=("Role", lambda s: "; ".join(sorted(set(s)))),
            AssignmentPaths=("AssignmentType", lambda s: "; ".join(sorted(set(s)))),
            Groups=("AssignedGroup", lambda s: "; ".join(sorted(set(s) - {"Unknown"}))),
            ObservedActivity=("HasObservedActivity", "max"),
            TotalSignIns=("TotalSignIns", "max"),
            ActiveDays=("ActiveDays", "max"),
            ResourceCount=("ResourceCount", "max"),
            LastSeen=("LastSeenDate", "max"),
            Resources=("Resources", lambda s: next((v for v in s if v), "")),
            Applications=("Applications", lambda s: next((v for v in s if v), "")),
        )
        .sort_values(["ObservedActivity", "TotalSignIns"], ascending=False)
    )
    st.dataframe(
        principal_summary,
        width="stretch",
        hide_index=True,
        column_config={
            "TotalSignIns": st.column_config.NumberColumn(format="localized"),
            "LastSeen": st.column_config.DatetimeColumn(format="YYYY-MM-DD HH:mm"),
        },
    )

# ------------------------------------------------------------
# Data
# ------------------------------------------------------------

with data_tab:
    st.subheader("Filtered dataset")
    st.dataframe(filtered, width="stretch", hide_index=True)
    st.download_button(
        "Download filtered CSV",
        data=filtered.to_csv(index=False).encode("utf-8-sig"),
        file_name="RoleUsageAnalysis-Filtered.csv",
        mime="text/csv",
    )

st.divider()
st.caption(
    "Use observed access patterns to scope conversations with role holders and owners. "
    "Validate workflows before removing or narrowing access."
)
