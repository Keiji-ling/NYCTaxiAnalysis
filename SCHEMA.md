# SCHEMA.md — NYCTaxiAnalysis

## Overview
- **Database:** NYCTaxiAnalysis
- **Table:** bronze_taxi_trips
- **Engine:** MergeTree
- **Partition:** toYYYYMM(tpep_pickup_datetime)
- **Order by:** (tpep_pickup_datetime, VendorID, PULocationID)
- **Total rows:** ~15.4 million
- **Date range:** 2008-12-31 to 2026-04-02

## Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| VendorID | UInt8 | Taxi vendor identifier (1, 2, 6, 7) |
| tpep_pickup_datetime | DateTime | Trip pickup timestamp |
| tpep_dropoff_datetime | DateTime | Trip dropoff timestamp |
| passenger_count | UInt8 | Number of passengers |
| trip_distance | Float32 | Trip distance in miles |
| RatecodeID | UInt8 | Rate code (0, 1–6, 99) |
| store_and_fwd_flag | LowCardinality(String) | Y/N — whether trip was stored before forwarding |
| PULocationID | UInt16 | Pickup location ID (taxi zone) |
| DOLocationID | UInt16 | Dropoff location ID (taxi zone) |
| payment_type | UInt8 | Payment method (0–4) |
| fare_amount | Float32 | Base fare |
| extra | Float32 | Extra charges |
| mta_tax | Float32 | MTA tax |
| tip_amount | Float32 | Tip amount |
| tolls_amount | Float32 | Toll charges |
| improvement_surcharge | Float32 | Improvement surcharge |
| total_amount | Float32 | Total trip cost |
| congestion_surcharge | Float32 | Congestion surcharge |
| airport_fee | Float32 | Airport fee |

## Data Distribution

### VendorID
| VendorID | Count |
|----------|-------|
| 2 | 12,229,574 |
| 1 | 2,937,879 |
| 7 | 191,158 |
| 6 | 23,601 |

### payment_type
| payment_type | Count |
|--------------|-------|
| 1 (Credit card) | 9,529,010 |
| 0 (Cash) | 4,252,605 |
| 2 (Dispute) | 1,342,219 |
| 4 (Credit card, duplicate?) | 195,923 |
| 3 (No charge) | 62,455 |

### store_and_fwd_flag
| Flag | Count |
|------|-------|
| N | 15,367,821 |
| Y | 14,391 |

### passenger_count
| Count | Rows |
|-------|------|
| 1 | 9,073,979 |
| 0 | 4,312,070 |
| 2 | 1,397,230 |
| 3 | 318,896 |
| 4 | 223,876 |
| 5 | 36,157 |
| 6 | 19,983 |
| 7+ | 21 |

### RatecodeID
| RatecodeID | Count | Notes |
|------------|-------|-------|
| 1 | 10,096,398 | Standard rate |
| 0 | 4,252,605 | Unknown/missing |
| 2 | 347,330 | JFK |
| 99 | 468,173 | Custom/other |
| 3 | 49,809 | Newark |
| 4 | 33,840 | Nassau/Westchester |
| 5 | 134,047 | Negotiated fare |
| 6 | 10 | Group ride |

## Observations

1. **Out-of-range records:** Two rows from 2008–2009 exist in the dataset. These are likely data anomalies and should be filtered out in silver/gold layers.
2. **Vendor 2 dominates:** ~79% of trips are from Vendor 2.
3. **Credit cards are most common:** ~62% of trips use payment_type 1 (credit card).
4. **store_and_fwd_flag is almost always N:** Only ~0.09% of trips have flag Y.
5. **passenger_count = 0 is common:** ~28% of trips report zero passengers — likely includes deadhead trips or data entry issues.
6. **RatecodeID 99 is significant:** 468k trips have a custom rate code.
7. **Date range spans 17+ years:** The dataset includes data from 2008 to 2026, though the bulk is from the latest 6 months ingested. The older records are likely from upstream data quirks.

---

## Silver Layer: silver_taxi_trips

- **File:** `clickhouse/materialized_views/silver_taxi_trips.sql`
- **Engine:** MergeTree
- **Partition:** toYYYYMM(pickup_date)
- **Order by:** (pickup_date, VendorID, PULocationID)
- **Source:** bronze_taxi_trips (materialized view)

### Transformations applied

| Category | Rule |
|----------|------|
| **Filter invalid** | `tpep_pickup_datetime >= '2010-01-01'` (drops 2008–2009 anomalies) |
| **Filter outliers** | `fare_amount > 0 AND total_amount > 0` |
| **Filter duration** | `trip_duration_minutes BETWEEN 1 AND 1440` (no zero-length or >24h trips) |
| **Derive time cols** | `pickup_date`, `pickup_hour`, `pickup_day_of_week`, `is_weekend` |
| **Derive metrics** | `trip_duration_minutes`, `avg_speed_mph`, `is_deadhead` |
| **Enrich labels** | `vendor_name`, `payment_type_desc`, `ratecode_desc` |

### Schema (bronze pass-through + derived columns)

| Column | Type | Description |
|--------|------|-------------|
| *(all bronze columns)* | *(unchanged)* | 19 original columns passed through |
| trip_duration_minutes | Int32 | dateDiff('minute', pickup, dropoff) |
| avg_speed_mph | Float32 | trip_distance / (duration_hours) |
| pickup_date | Date | toDate(tpep_pickup_datetime) |
| pickup_hour | UInt8 | toHour(tpep_pickup_datetime) |
| pickup_day_of_week | UInt8 | toDayOfWeek(tpep_pickup_datetime) |
| is_weekend | UInt8 | 1 if Saturday/Sunday, else 0 |
| is_deadhead | UInt8 | 1 if passenger_count = 0 |
| payment_type_desc | String | Human-readable: 'Credit card', 'Cash', etc. |
| ratecode_desc | String | Human-readable: 'Standard rate', 'JFK', etc. |
| vendor_name | String | Human-readable: 'VeriFone', 'Creative Mobile Tech', etc. |

---

## Gold Layer: Aggregated Views

All gold views use **SummingMergeTree** and store only summable columns (`count()`, `sum(...)`). Averages should be computed at query time (e.g., `total_fare / trip_count`). Pre-computed metrics are documented per view below.

### gold_daily_stats
- **File:** `clickhouse/queries/gold_daily_stats.sql`
- **Purpose:** Daily operational metrics by vendor and payment type
- **KT dimension:** WHAT (vendor, payment_type)
- **Partition:** toYear(pickup_date)
- **Order by:** (pickup_date, VendorID, vendor_name, payment_type, payment_type_desc)

| Column | Type | Description |
|--------|------|-------------|
| pickup_date | Date | Day of trip pickup |
| VendorID | UInt8 |  |
| vendor_name | String |  |
| payment_type | UInt8 |  |
| payment_type_desc | String |  |
| trip_count | UInt64 | Number of trips |
| total_passengers | UInt64 | Sum of passenger_count |
| total_distance | Float64 | Sum of trip_distance |
| total_duration_min | UInt64 | Sum of trip_duration_minutes |
| total_fare | Float64 | Sum of fare_amount |
| total_tip | Float64 | Sum of tip_amount |
| total_tolls | Float64 | Sum of tolls_amount |
| total_revenue | Float64 | Sum of total_amount |
| total_surcharges | Float64 | Sum of extra + mta_tax + surcharges |

Query-time averages: `SELECT total_fare / trip_count AS avg_fare, total_tip / trip_count AS avg_tip FROM gold_daily_stats`

### gold_route_analytics
- **File:** `clickhouse/queries/gold_route_analytics.sql`
- **Purpose:** Zone-to-zone route analysis
- **KT dimension:** WHERE (pickup/dropoff zone)
- **Partition:** toYear(pickup_date)
- **Order by:** (pickup_date, PULocationID, DOLocationID)

| Column | Type | Description |
|--------|------|-------------|
| pickup_date | Date |  |
| PULocationID | UInt16 | Pickup taxi zone |
| DOLocationID | UInt16 | Dropoff taxi zone |
| trip_count | UInt64 |  |
| total_fare | Float64 |  |
| total_tip | Float64 |  |
| total_distance | Float64 |  |
| total_revenue | Float64 |  |
| total_duration_min | UInt64 |  |

### gold_time_series
- **File:** `clickhouse/queries/gold_time_series.sql`
- **Purpose:** Hourly aggregations for trend analysis
- **KT dimension:** WHEN (hour, day, weekend vs weekday)
- **Partition:** toYear(pickup_date)
- **Order by:** (pickup_date, pickup_hour, is_weekend)

| Column | Type | Description |
|--------|------|-------------|
| pickup_date | Date |  |
| pickup_hour | UInt8 | 0–23 |
| is_weekend | UInt8 |  |
| trip_count | UInt64 |  |
| total_passengers | UInt64 |  |
| total_revenue | Float64 |  |
| total_duration_min | UInt64 |  |
| total_distance | Float64 |  |
| total_fare | Float64 |  |
| total_tip | Float64 |  |

### gold_vendor_monthly
- **File:** `clickhouse/queries/gold_vendor_monthly.sql`
- **Purpose:** Monthly vendor comparison
- **KT dimension:** WHAT (vendor), TO WHAT EXTENT (market share)
- **Partition:** toYear(month)
- **Order by:** (month, VendorID, vendor_name)

| Column | Type | Description |
|--------|------|-------------|
| month | Date | First of month (toStartOfMonth) |
| VendorID | UInt8 |  |
| vendor_name | String |  |
| trip_count | UInt64 |  |
| total_revenue | Float64 |  |
| total_tip | Float64 |  |
| total_distance | Float64 |  |
| total_duration_min | UInt64 |  |
| total_passengers | UInt64 |  |
| total_fare | Float64 |  |

### gold_kt_benchmarks
- **File:** `clickhouse/queries/gold_kt_benchmarks.sql`
- **Purpose:** Unified dimension-slice benchmark for Kepner-Tregoe Is/Is Not analysis
- **KT dimensions:** All 5 — WHAT, WHERE, WHEN, TO WHAT EXTENT, WHAT IS NOT
- **Partition:** toYear(slice_date)
- **Order by:** (dimension, slice_date, slice_key)

| Column | Type | Description |
|--------|------|-------------|
| dimension | String | One of: vendor, payment_type, pickup_zone, hour, rate_code |
| slice_date | Date | First of month (toStartOfMonth) |
| slice_key | UInt16 | The dimension value as a uniform key |
| slice_label | String | Human-readable label for the slice |
| trip_count | UInt64 |  |
| total_fare | Float64 |  |
| total_tip | Float64 |  |
| total_revenue | Float64 |  |
| total_distance | Float64 |  |
| total_duration_min | UInt64 |  |
| total_passengers | UInt64 |  |

#### Query patterns for KT analysis

```sql
-- IS: suspect slice (Vendor 2, March 2026)
SELECT * FROM gold_kt_benchmarks
WHERE dimension = 'vendor' AND slice_key = 2
  AND slice_date = '2026-03-01';

-- IS NOT: comparison slice (Vendor 1, same month)
SELECT * FROM gold_kt_benchmarks
WHERE dimension = 'vendor' AND slice_key = 1
  AND slice_date = '2026-03-01';

-- Historical baseline (6-month average for Vendor 2)
SELECT avg(trip_count) AS avg_monthly_trips,
       avg(total_revenue) AS avg_monthly_revenue
FROM gold_kt_benchmarks
WHERE dimension = 'vendor' AND slice_key = 2
  AND slice_date BETWEEN '2025-10-01' AND '2026-02-01';
```
