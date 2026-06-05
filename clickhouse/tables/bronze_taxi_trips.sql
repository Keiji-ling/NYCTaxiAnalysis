CREATE TABLE IF NOT EXISTS NYCTaxiAnalysis.bronze_taxi_trips
(
    VendorID            UInt8,
    tpep_pickup_datetime DateTime,
    tpep_dropoff_datetime DateTime,
    passenger_count     UInt8,
    trip_distance       Float32,
    RatecodeID          UInt8,
    store_and_fwd_flag  LowCardinality(String),
    PULocationID        UInt16,
    DOLocationID        UInt16,
    payment_type        UInt8,
    fare_amount         Float32,
    extra               Float32,
    mta_tax             Float32,
    tip_amount          Float32,
    tolls_amount        Float32,
    improvement_surcharge Float32,
    total_amount        Float32,
    congestion_surcharge Float32,
    airport_fee         Float32
)
ENGINE = MergeTree()
ORDER BY (tpep_pickup_datetime, VendorID, PULocationID)
PARTITION BY toYYYYMM(tpep_pickup_datetime);
