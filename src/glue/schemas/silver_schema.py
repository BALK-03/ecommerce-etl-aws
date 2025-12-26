from pyspark.sql.types import (
    StructType, StructField,
    StringType, IntegerType, TimestampType, DecimalType, BooleanType
)

silver_schema = StructType([
    StructField("source_system", StringType(), True),
    StructField("ingestion_timestamp", TimestampType(), True),
    StructField("schema_version", StringType(), True),

    StructField("order_id", IntegerType(), False),      # enforced by quality gate
    StructField("customer_id", IntegerType(), True),
    StructField("product_id", IntegerType(), True),
    StructField("amount", DecimalType(10, 2), False),   # enforced by quality gate
    StructField("currency", StringType(), True),
    StructField("event_timestamp", TimestampType(), True),

    StructField("region", StringType(), True),
    StructField("region_inferred", BooleanType(), False),

    StructField("year", IntegerType(), True),
    StructField("month", IntegerType(), True)
])
