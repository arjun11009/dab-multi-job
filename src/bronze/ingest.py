import sys

# Add project root (DAB automatically places files correctly)
sys.path.append("/Workspace/Users/ranaarju0031@gmail.com/.bundle/multi-job-poc/dev/files/src")

from common.reader import create_sample_data
from common.writer import log_output

from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

df = create_sample_data(spark)

log_output(df, "Bronze")

print("Bronze job completed")
print("bronze updated test")
print("Testing the bronze test")
