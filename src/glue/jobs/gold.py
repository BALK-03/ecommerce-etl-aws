import sys
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

df = glueContext.create_dynamic_frame.from_catalog(
    database="badr_datalake", 
    table_name="orders"
).toDF()

# Daily Revenue by Region
daily_revenue = df.groupBy("region", "year", "month") \
    .agg(F.round(F.sum("amount"), 2).alias("revenue"))

# Top 5 Products by Region
window_spec = Window.partitionBy("region").orderBy(F.col("total_sales").desc())

top_products = df.groupBy("region", "product_id") \
    .agg(F.count("order_id").alias("total_sales")) \
    .withColumn("rank", F.rank().over(window_spec)) \
    .filter(F.col("rank") <= 5)


GOLD_BASE = "s3://badr-datalake-gold-us-east-1/"

daily_revenue.write.mode("overwrite").parquet(f"{GOLD_BASE}daily_revenue/")
top_products.write.mode("overwrite").parquet(f"{GOLD_BASE}top_products/")

job.commit()