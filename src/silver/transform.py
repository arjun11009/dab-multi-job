import sys

sys.path.append("/Workspace/Users/ranaarju0031@gmail.com/.bundle/multi-job-poc/dev/files/src")

from common.reader import create_sample_data
from common.validator import validate_not_null
from common.writer import log_output

from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

df = create_sample_data(spark)

df_clean = validate_not_null(df, "amount")

log_output(df_clean, "Silver")

print("Silver job completed")
print("Testing the silver chnages in the files ")