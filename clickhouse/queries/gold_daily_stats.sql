-- gold_daily_stats
-- Per-day aggregations (one row per date).
-- Use: daily revenue, tip rate trends, overall volume.

CREATE MATERIALIZED VIEW IF NOT EXISTS NYCTaxiAnalysis.gold_daily_stats
ENGINE = SummingMergeTree()
PARTITION BY toYear(pickup_date)
ORDER BY pickup_date
POPULATE
AS SELECT
    pickup_date,
    count()                                  AS trip_count,
    sum(passenger_count)                     AS total_passengers,
    sum(trip_distance)                       AS total_distance,
    sum(trip_duration_minutes)               AS total_duration_min,
    sum(fare_amount)                         AS total_fare,
    sum(tip_amount)                          AS total_tip,
    sum(tolls_amount)                        AS total_tolls,
    sum(total_amount)                        AS total_revenue,
    sum(extra + mta_tax + improvement_surcharge + congestion_surcharge + airport_fee)
                                             AS total_surcharges
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY pickup_date;
