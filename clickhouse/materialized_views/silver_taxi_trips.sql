CREATE MATERIALIZED VIEW IF NOT EXISTS NYCTaxiAnalysis.silver_taxi_trips
ENGINE = MergeTree()
PARTITION BY toYYYYMM(pickup_date)
ORDER BY (pickup_date, VendorID, PULocationID)
POPULATE
AS SELECT
    -- All original bronze columns (pass-through)
    VendorID,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    RatecodeID,
    store_and_fwd_flag,
    PULocationID,
    DOLocationID,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    airport_fee,

    -- Derived time columns
    dateDiff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) AS trip_duration_minutes,
    round(trip_distance / greatest(dateDiff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) / 60, 1), 2) AS avg_speed_mph,
    toDate(tpep_pickup_datetime) AS pickup_date,
    toHour(tpep_pickup_datetime) AS pickup_hour,
    toDayOfWeek(tpep_pickup_datetime) AS pickup_day_of_week,
    toDayOfWeek(tpep_pickup_datetime) IN (6, 7) AS is_weekend,
    passenger_count = 0 AS is_deadhead,

    -- Human-readable code mappings
    multiIf(
        payment_type = 1, 'Credit card',
        payment_type = 0, 'Cash',
        payment_type = 2, 'Dispute',
        payment_type = 3, 'No charge',
        payment_type = 4, 'Credit card (dup)',
        'Unknown'
    ) AS payment_type_desc,

    multiIf(
        RatecodeID = 1, 'Standard rate',
        RatecodeID = 2, 'JFK',
        RatecodeID = 3, 'Newark',
        RatecodeID = 4, 'Nassau/Westchester',
        RatecodeID = 5, 'Negotiated fare',
        RatecodeID = 6, 'Group ride',
        RatecodeID = 99, 'Custom',
        'Other'
    ) AS ratecode_desc,

    multiIf(
        VendorID = 1, 'Creative Mobile Tech',
        VendorID = 2, 'VeriFone',
        VendorID = 6, 'Vendor 6',
        VendorID = 7, 'Vendor 7',
        'Unknown'
    ) AS vendor_name

FROM NYCTaxiAnalysis.bronze_taxi_trips
WHERE tpep_pickup_datetime >= '2010-01-01'
  AND fare_amount > 0
  AND total_amount > 0
  AND dateDiff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) BETWEEN 1 AND 1440;
