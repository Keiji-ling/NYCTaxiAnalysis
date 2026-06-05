-- gold_time_series
-- Hourly aggregations with weekend flag.
-- KT dimension: WHEN (hour, day, weekend vs weekday).
-- Use: peak hour detection, YoY/WoW trend comparison, capacity planning.

CREATE MATERIALIZED VIEW IF NOT EXISTS NYCTaxiAnalysis.gold_time_series
ENGINE = SummingMergeTree()
PARTITION BY toYear(pickup_date)
ORDER BY (pickup_date, pickup_hour, is_weekend)
POPULATE
AS SELECT
    pickup_date,
    pickup_hour,
    is_weekend,
    count()                        AS trip_count,
    sum(passenger_count)           AS total_passengers,
    sum(total_amount)              AS total_revenue,
    sum(trip_duration_minutes)     AS total_duration_min,
    sum(trip_distance)             AS total_distance,
    sum(fare_amount)               AS total_fare,
    sum(tip_amount)                AS total_tip
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY pickup_date, pickup_hour, is_weekend;
