-- gold_kt_benchmarks
-- Unified dimension-slice benchmark table for Kepner-Tregoe Is/Is Not analysis.
-- Each row represents one slice of one dimension for one month.
-- Supports all 5 KT dimensions:
--   WHAT      → vendor, payment_type, rate_code
--   WHERE     → pickup_zone
--   WHEN      → hour
--   TO WHAT EXTENT → numeric metrics (trip_count, total_revenue, etc.)
--   WHAT IS NOT → compare any slice against any other via dimension filter
--
-- Query pattern for KT analysis:
--   -- Find IS (suspect slice):
--   SELECT * FROM gold_kt_benchmarks
--   WHERE dimension = 'vendor' AND slice_key = 2 AND slice_date = '2026-03-01';
--
--   -- Find IS NOT (comparison slice):
--   SELECT * FROM gold_kt_benchmarks
--   WHERE dimension = 'vendor' AND slice_key = 1 AND slice_date = '2026-03-01';
--
--   -- Compare against historical baseline:
--   SELECT avg(trip_count), avg(total_revenue)
--   FROM gold_kt_benchmarks
--   WHERE dimension = 'vendor' AND slice_key = 2
--     AND slice_date BETWEEN '2025-10-01' AND '2026-02-01';

CREATE MATERIALIZED VIEW IF NOT EXISTS NYCTaxiAnalysis.gold_kt_benchmarks
ENGINE = SummingMergeTree()
PARTITION BY toYear(slice_date)
ORDER BY (dimension, slice_date, slice_key)
POPULATE
AS
SELECT
    'vendor' AS dimension,
    toStartOfMonth(pickup_date) AS slice_date,
    toUInt16(VendorID) AS slice_key,
    vendor_name AS slice_label,
    count() AS trip_count,
    sum(fare_amount) AS total_fare,
    sum(tip_amount) AS total_tip,
    sum(total_amount) AS total_revenue,
    sum(trip_distance) AS total_distance,
    sum(trip_duration_minutes) AS total_duration_min,
    sum(passenger_count) AS total_passengers
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY dimension, slice_date, slice_key, slice_label

UNION ALL

SELECT
    'payment_type' AS dimension,
    toStartOfMonth(pickup_date) AS slice_date,
    toUInt16(payment_type) AS slice_key,
    payment_type_desc AS slice_label,
    count() AS trip_count,
    sum(fare_amount) AS total_fare,
    sum(tip_amount) AS total_tip,
    sum(total_amount) AS total_revenue,
    sum(trip_distance) AS total_distance,
    sum(trip_duration_minutes) AS total_duration_min,
    sum(passenger_count) AS total_passengers
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY dimension, slice_date, slice_key, slice_label

UNION ALL

SELECT
    'pickup_zone' AS dimension,
    toStartOfMonth(pickup_date) AS slice_date,
    toUInt16(PULocationID) AS slice_key,
    toString(PULocationID) AS slice_label,
    count() AS trip_count,
    sum(fare_amount) AS total_fare,
    sum(tip_amount) AS total_tip,
    sum(total_amount) AS total_revenue,
    sum(trip_distance) AS total_distance,
    sum(trip_duration_minutes) AS total_duration_min,
    sum(passenger_count) AS total_passengers
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY dimension, slice_date, slice_key, slice_label

UNION ALL

SELECT
    'hour' AS dimension,
    toStartOfMonth(pickup_date) AS slice_date,
    toUInt16(pickup_hour) AS slice_key,
    toString(pickup_hour) AS slice_label,
    count() AS trip_count,
    sum(fare_amount) AS total_fare,
    sum(tip_amount) AS total_tip,
    sum(total_amount) AS total_revenue,
    sum(trip_distance) AS total_distance,
    sum(trip_duration_minutes) AS total_duration_min,
    sum(passenger_count) AS total_passengers
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY dimension, slice_date, slice_key, slice_label

UNION ALL

SELECT
    'rate_code' AS dimension,
    toStartOfMonth(pickup_date) AS slice_date,
    toUInt16(RatecodeID) AS slice_key,
    ratecode_desc AS slice_label,
    count() AS trip_count,
    sum(fare_amount) AS total_fare,
    sum(tip_amount) AS total_tip,
    sum(total_amount) AS total_revenue,
    sum(trip_distance) AS total_distance,
    sum(trip_duration_minutes) AS total_duration_min,
    sum(passenger_count) AS total_passengers
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY dimension, slice_date, slice_key, slice_label;
