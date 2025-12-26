from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType

metadata_schema = StructType([
    StructField('source_system', StringType(), True),
    StructField('ingestion_timestamp', TimestampType(), True),
    StructField('schema_version', StringType(), True)
])

payload_schema = StructType([
    StructField('order_id', IntegerType(), True), 
    StructField('customer_id', IntegerType(), True),
    StructField('product_id', IntegerType(), True),
    StructField('amount', StringType(), True),
    StructField('currency', StringType(), True),
    StructField('event_timestamp', StringType(), True),
    StructField('region', StringType(), True)
])

final_schema = StructType([
    StructField('metadata', metadata_schema, True),
    StructField('payload', payload_schema, True)
])