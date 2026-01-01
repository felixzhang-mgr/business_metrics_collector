import sys
import time
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import col, date_format, when, lit
from pyspark.sql.types import TimestampType, LongType

# ==============================================================================
# Glue 3.0 / Spark 3.1 / Python 3
# Production script: Periodic incremental ETL for trade_5m data
# Oracle (via Glue Connection: paytend-readonly-olap) -> S3 (paytend-olap-eu-central-1)
# Runs every 5 minutes: Pull last 10 minutes from pre-aggregated 5-minute view
# ==============================================================================

def log(msg: str):
    print(f"[INFO] {msg}", flush=True)

t0 = time.time()
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

job = Job(glueContext)
job.init(args["JOB_NAME"], args)

log("Job initialized (Glue 3.0 / Spark 3.1 / Python 3)")

# ------------------------------------------------------------------------------
# Settings
# ------------------------------------------------------------------------------
CONNECTION_NAME = "paytend-readonly-olap"
S3_OUT = "s3://paytend-olap-eu-central-1/trade_5m/trade_createdate_5m/"
VIEW_NAME = "PAYTEND.V_TRADE_CT_5M"

# Pull last 10 minutes from view; view is already 5-min aggregated.
# Covers last 2 windows to handle delays and backfill.
# Using Oracle SYSDATE arithmetic to avoid timezone mismatches.
SAMPLE_QUERY = (
    "SELECT window_start, AUDITSTATUS, PAYMENTTYPE, TRADE_STATUS, TRADE_TYPE, TXSTEP, cnt "
    f"FROM {VIEW_NAME} "
    "WHERE window_start >= SYSDATE - (10 / (24 * 60)) "
    "ORDER BY window_start"
)

log(f"Connection: {CONNECTION_NAME}")
log(f"Source view: {VIEW_NAME}")
log(f"Time window: Last 10 minutes (SYSDATE - 10 minutes)")
log(f"Target S3: {S3_OUT}")

# ------------------------------------------------------------------------------
# 1) Read from Oracle view (predicate pushdown via sampleQuery)
# ------------------------------------------------------------------------------
log("Starting Oracle read...")
read_t0 = time.time()
dyf = glueContext.create_dynamic_frame.from_options(
    connection_type="oracle",
    connection_options={
        "useConnectionProperties": "true",
        "connectionName": CONNECTION_NAME,
        "dbtable": VIEW_NAME,
        "sampleQuery": SAMPLE_QUERY
    },
    transformation_ctx="oracle_view_read"
)
log(f"Oracle read DynamicFrame created in {time.time() - read_t0:.2f}s")

df = dyf.toDF()

# ------------------------------------------------------------------------------
# 2) Schema normalization and partition column
# ------------------------------------------------------------------------------
log("Normalizing schema and adding partition column...")
df2 = (
    df
    .withColumn("window_start", col("WINDOW_START").cast(TimestampType()))
    .withColumn("dt", date_format(col("WINDOW_START").cast(TimestampType()), "yyyy-MM-dd"))
    # Convert NUMBER fields to string, handle null values with default ""
    .withColumn("auditstatus", when(col("AUDITSTATUS").isNull(), lit("")).otherwise(col("AUDITSTATUS").cast("string")))
    .withColumn("paymenttype", when(col("PAYMENTTYPE").isNull(), lit("")).otherwise(col("PAYMENTTYPE").cast("string")))
    .withColumn("trade_status", when(col("TRADE_STATUS").isNull(), lit("")).otherwise(col("TRADE_STATUS").cast("string")))
    .withColumn("trade_type", when(col("TRADE_TYPE").isNull(), lit("")).otherwise(col("TRADE_TYPE").cast("string")))
    .withColumn("txstep", when(col("TXSTEP").isNull(), lit("")).otherwise(col("TXSTEP").cast("string")))
    .withColumn("cnt", col("CNT").cast(LongType()))
)

cnt_t0 = time.time()
row_count = df2.count()
log(f"Oracle read completed. Rows processed: {row_count:,} (computed in {time.time() - cnt_t0:.2f}s)")

# ------------------------------------------------------------------------------
# 3) Write to S3 (Parquet) with daily partitioning
# ------------------------------------------------------------------------------
if row_count > 0:
    log("Starting S3 write (Parquet format, partitioned by dt, append mode)...")
    write_t0 = time.time()
    
    # Repartition by dt to ensure proper data distribution
    # For incremental loads, coalesce to reasonable number of files
    # partitionBy("dt") automatically excludes dt from Parquet data files (only in partition path)
    df_final = df2.repartition("dt").coalesce(5)
    
    df_final.write \
        .mode("append") \
        .option("compression", "snappy") \
        .partitionBy("dt") \
        .parquet(S3_OUT)
    
    log(f"S3 write completed in {time.time() - write_t0:.2f}s")
else:
    log("No rows to write, skipping S3 write")

job.commit()
log(f"Job completed successfully. Total elapsed time: {time.time() - t0:.2f}s")

