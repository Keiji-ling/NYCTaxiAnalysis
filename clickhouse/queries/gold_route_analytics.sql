-- gold_route_analytics
-- Zone-to-zone aggregations per day.
-- KT dimension: WHERE (pickup/dropoff zone).
-- Use: popular routes, fare variance by route, airport trip analysis.

CREATE MATERIALIZED VIEW IF NOT EXISTS NYCTaxiAnalysis.gold_route_analytics
ENGINE = SummingMergeTree()
PARTITION BY toYear(pickup_date)
ORDER BY (pickup_date, PULocationID, DOLocationID)
POPULATE
AS SELECT
    pickup_date,
    PULocationID,
    DOLocationID,
    count()              AS trip_count,
    sum(fare_amount)     AS total_fare,
    sum(tip_amount)      AS total_tip,
    sum(trip_distance)   AS total_distance,
    sum(total_amount)    AS total_revenue,
    sum(trip_duration_minutes) AS total_duration_min
FROM NYCTaxiAnalysis.silver_taxi_trips
GROUP BY pickup_date, PULocationID, DOLocationID;
