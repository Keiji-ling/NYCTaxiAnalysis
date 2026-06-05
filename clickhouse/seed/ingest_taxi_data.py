"""
Ingests the latest 6 months of NYC yellow taxi trip data into bronze_taxi_trips.
Downloads Parquet files from the TLC public dataset and inserts via clickhouse_connect.
"""

import os
import sys
import requests
import pandas as pd
from datetime import datetime, timedelta
from dotenv import load_dotenv
import clickhouse_connect

load_dotenv()

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_"
TABLE = "NYCTaxiAnalysis.bronze_taxi_trips"

COLUMNS = [
    "VendorID",
    "tpep_pickup_datetime",
    "tpep_dropoff_datetime",
    "passenger_count",
    "trip_distance",
    "RatecodeID",
    "store_and_fwd_flag",
    "PULocationID",
    "DOLocationID",
    "payment_type",
    "fare_amount",
    "extra",
    "mta_tax",
    "tip_amount",
    "tolls_amount",
    "improvement_surcharge",
    "total_amount",
    "congestion_surcharge",
    "airport_fee",
]

def get_client():
    return clickhouse_connect.get_client(
        host=os.getenv("CLICKHOUSE_HOST"),
        port=int(os.getenv("CLICKHOUSE_PORT", 8443)),
        username=os.getenv("CLICKHOUSE_USER"),
        password=os.getenv("CLICKHOUSE_PASSWORD"),
        secure=True,
        verify=False,
    )


def get_months():
    """Return the latest 6 year-month strings (YYYY-MM), most recent first."""
    now = datetime.now()
    months = []
    for i in range(6):
        year = now.year
        month = now.month - i
        while month < 1:
            month += 12
            year -= 1
        months.append(f"{year}-{month:02d}")
    return months


def download_parquet(ym: str) -> pd.DataFrame | None:
    url = f"{BASE_URL}{ym}.parquet"
    print(f"Downloading {url} ...")
    resp = requests.get(url, timeout=120)
    if resp.status_code in (404, 403):
        print(f"  No data available for {ym}, skipping.")
        return None
    resp.raise_for_status()
    df = pd.read_parquet(pd.io.common.BytesIO(resp.content))
    print(f"  Read {len(df)} rows for {ym}.")
    return df


def coerce_types(df: pd.DataFrame) -> pd.DataFrame:
    """Ensure column types match the ClickHouse table definition."""
    for col in ["VendorID", "passenger_count", "RatecodeID", "payment_type"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype("Int64")
    for col in ["PULocationID", "DOLocationID"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype("Int64")
    for col in [
        "trip_distance",
        "fare_amount",
        "extra",
        "mta_tax",
        "tip_amount",
        "tolls_amount",
        "improvement_surcharge",
        "total_amount",
        "congestion_surcharge",
        "airport_fee",
    ]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0).astype("float32")
    if "store_and_fwd_flag" in df.columns:
        df["store_and_fwd_flag"] = df["store_and_fwd_flag"].fillna("N").astype(str).str.strip()
        df.loc[df["store_and_fwd_flag"].isin(["None", "", "nan"]), "store_and_fwd_flag"] = "N"
    for col in ["tpep_pickup_datetime", "tpep_dropoff_datetime"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def main():
    client = get_client()
    months = get_months()
    print(f"Target months: {months}")

    total_inserted = 0
    for ym in months:
        df = download_parquet(ym)
        if df is None:
            continue

        # Keep only columns that exist in the table
        available = [c for c in COLUMNS if c in df.columns]
        df = df[available]
        df = coerce_types(df)

        # Replace NaT with a sentinel that ClickHouse can accept
        for col in ["tpep_pickup_datetime", "tpep_dropoff_datetime"]:
            if col in df.columns:
                df[col] = df[col].fillna(pd.Timestamp("1970-01-01"))

        # Convert nullable Int64 to plain int for clickhouse_connect
        for col in df.select_dtypes(include=["Int64"]).columns:
            df[col] = df[col].astype("int64")

        print(f"Inserting {len(df)} rows for {ym} ...")
        client.insert_df(TABLE, df)
        total_inserted += len(df)
        print(f"  Done. Total so far: {total_inserted}")

    print(f"\nIngestion complete. {total_inserted} rows inserted.")


if __name__ == "__main__":
    main()
