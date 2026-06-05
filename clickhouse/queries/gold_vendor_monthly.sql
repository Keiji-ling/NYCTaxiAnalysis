-- gold_vendor_monthly
-- Monthly aggregations per vendor.
-- KT dimension: WHAT (vendor), TO WHAT EXTENT (market share, revenue share).
-- Use: vendor market share, monthly revenue comparison, performance benchmarking.

CREATE MATERIALIZED VIEW IF NOT EXISTS NYCTaxiAnalysis.gold_vendor_monthly
ENGINE = SummingMergeTree()
PARTITION BY toYear(month)
ORDER BY (month, VendorID, vendor_name)
POPULATE
AS SELECT
    toStartOfMonth(pickup_date) AS month,
    VendorID,
    vendor_name,
    count()                  AS trip_count,
    sum(total_amount)        AS total_revenue,
    sum(tip_amount)          AS total_tip,
    sum(trip_distance)       AS total_distance,
    sum(trip_duration_minutes) AS total_duration_min,
    sum(passenger_count)     AS total_passengers,
    sum(fare_amount)         AS total_fare
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY month, VendorID, vendor_name;
