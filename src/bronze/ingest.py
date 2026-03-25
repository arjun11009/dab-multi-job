import sys
import os

# Add src folder to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common.reader import create_sample_data
from common.writer import log_output

from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

df = create_sample_data(spark)

log_output(df, "Bronze")

print("Bronze job completed")