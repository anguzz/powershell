import pandas as pd
import numpy as np
import streamlit as st
import plotly.express as px
from datetime import datetime

# -----------------------
# Config
# -----------------------
CSV_PATH = "AD-Groups-Inventory.csv"

# -----------------------
# Helpers
# -----------------------
@st.cache_data
def load_data(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, dtype=str, encoding="utf-8")
    df.replace({"": np.nan}, inplace=True)

    # Normalize join key
    if "GroupSamAccountName" in df.columns:
        df["GroupSamAccountName"] = df["GroupSamAccountName"].str.lower().str.strip()

    # Coerce numeric
    if "MemberCount" in df.columns:
        df["MemberCount"] = pd.to_numeric(df["MemberCount"], errors="coerce").fillna(0)

    if "IsEmpty" in df.columns:
        df["IsEmpty"] = df["IsEmpty"].astype(str).str.lower().isin(["true", "1", "yes"])

    # Dates
    for c in ["whenCreated", "whenChanged"]:
        if c in df.columns:
            df[c] = pd.to_datetime(df[c], errors="coerce")

    # Derived metrics
    now = pd.Timestamp.now()

    df["AgeDays"] = (now - df["whenCreated"]).dt.days
    df["StaleDays"] = (now - df["whenChanged"]).dt.days

    df["HasOwner"] = df["ManagedBy"].fillna("").str.strip() != ""
    df["HasDescription"] = df["Description"].fillna("").str.strip() != ""

    # Simple scoring model
    df["CandidateScore"] = 0

    df.loc[df["IsEmpty"] == True, "CandidateScore"] += 40
    df.loc[df["StaleDays"] > 365, "CandidateScore"] += 30
    df.loc[~df["HasOwner"], "CandidateScore"] += 15
    df.loc[~df["HasDescription"], "CandidateScore"] += 15

    # Buckets
    df["CleanupBucket"] = "D: Low Signal"
    df.loc[(df["IsEmpty"]) & (df["StaleDays"] > 365), "CleanupBucket"] = "A: High Priority"
    df.loc[(df["StaleDays"] > 365), "CleanupBucket"] = "B: Review"
    df.loc[(df["StaleDays"] <= 365), "CleanupBucket"] = "C: Active"

    return df

def download_csv(df: pd.DataFrame) -> bytes:
    return df.to_csv(index=False).encode("utf-8")

# -----------------------
# App
# -----------------------
st.set_page_config(page_title="AD Group Cleanup Dashboard", layout="wide")
st.title("AD Group Cleanup Dashboard (AD Only)")

df = load_data(CSV_PATH)

# Sidebar
st.sidebar.header("Filters")

bucket_sel = st.sidebar.multiselect(
    "CleanupBucket",
    df["CleanupBucket"].unique(),
    default=df["CleanupBucket"].unique()
)
df_view = df[df["CleanupBucket"].isin(bucket_sel)]

empty_sel = st.sidebar.multiselect("IsEmpty", [True, False], default=[True, False])
df_view = df_view[df_view["IsEmpty"].isin(empty_sel)]

min_score = st.sidebar.slider("Min CandidateScore", 0, 100, 0)
df_view = df_view[df_view["CandidateScore"] >= min_score]

search = st.sidebar.text_input("Search (Name / Sam / DN / GUID)")
if search:
    s = search.lower()
    df_view = df_view[
        df_view.astype(str).apply(lambda row: row.str.lower().str.contains(s).any(), axis=1)
    ]

# KPIs
c1, c2, c3, c4 = st.columns(4)

c1.metric("Groups", f"{len(df_view):,}")
c2.metric("Empty", int(df_view["IsEmpty"].sum()))
c3.metric("Avg StaleDays", int(df_view["StaleDays"].fillna(0).mean()))
c4.metric("Avg Score", round(df_view["CandidateScore"].mean(), 1))

st.divider()

# Charts
left, right = st.columns(2)

bucket_counts = df_view["CleanupBucket"].value_counts().reset_index()
bucket_counts.columns = ["Bucket", "Count"]

left.plotly_chart(px.bar(bucket_counts, x="Bucket", y="Count", title="Buckets"))

if "MemberCount" in df_view.columns:
    right.plotly_chart(
        px.histogram(df_view, x="MemberCount", nbins=40, title="MemberCount Distribution")
    )

st.divider()

# Table
st.subheader("Candidates")

cols = [
    "Name", "SamAccountName", "MemberCount", "IsEmpty",
    "StaleDays", "AgeDays", "CandidateScore", "CleanupBucket",
    "ManagedBy", "Description", "DistinguishedName"
]

st.dataframe(df_view[cols].sort_values(by="CandidateScore", ascending=False))

st.download_button(
    "Download filtered CSV",
    data=download_csv(df_view),
    file_name="AD-Groups-Filtered.csv"
)
