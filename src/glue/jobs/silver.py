import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import DecimalType
from schemas.bronze_schema import final_schema

# AWS Glue Context Initialization Template
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

BRONZE_PATH = "s3://badr-datalake-bronze-us-east-1/orders/"
SILVER_PATH = "s3://badr-datalake-silver-us-east-1/orders/"
DLQ_PATH = "s3://badr-datalake-dlq-us-east-1/poison_records/"


df = spark.read.json(BRONZE_PATH, schema=final_schema)

# Flattening
df_flat = df.select('metadata.*', 'payload.*')

# Region imputation
mode_df = (
    df_flat
    .groupBy("region")
    .count()
    .orderBy(F.col("count").desc())
    .limit(1)
    .select(F.col("region").alias("mode_val"))
)

df_flat = df_flat.crossJoin(F.broadcast(mode_df)) \
    .withColumn(
    'region_inferred',
    F.when(F.col('region').isNull(), True).otherwise(False)
    ) \
    .withColumn(
        'region',
        F.when(F.col('region').isNotNull(), F.col('region')) \
        .when(F.col('currency') == 'USD', F.col('mode_val')) \
        .when(F.col('currency').isin(['MAD', 'EUR']), 'EMEA') \
        .otherwise('unknown')     # If region is null and currency not the classic values
    ) \
    .drop('mode_val')

df_transformed = df_flat \
    .withColumn('amount', F.regexp_replace(F.trim(F.col('amount')), r'STR_ERROR_', '').cast(DecimalType(10, 2))) \
    .withColumn('event_timestamp', F.coalesce(
        F.to_timestamp(F.col('event_timestamp'), "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        F.to_timestamp(F.col('event_timestamp'), 'dd-MM-yyyy HH:mm:ss'))) \
    .withColumn('year', F.year('event_timestamp')) \
    .withColumn('month', F.month('event_timestamp'))

# Quality gate
is_poison = (F.col('order_id').isNull()) | (F.col('amount').isNull())
dlq_df = df_transformed.where(is_poison)
silver_valid = df_transformed.where(~is_poison)

# Deduplication
window_spec = Window.partitionBy('order_id').orderBy(F.col('ingestion_timestamp').desc())
silver_final = silver_valid.withColumn('rn', F.row_number().over(window_spec)) \
    .where(F.col('rn') == 1).drop('rn')

# Saving silver data
silver_final.write.mode("overwrite") \
    .option("partitionOverwriteMode", "dynamic") \
    .partitionBy("region", "year", "month") \
    .parquet(SILVER_PATH)

# Saving poison data for audit
dlq_df.write.mode("append").parquet(DLQ_PATH)

job.commit()