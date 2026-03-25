import sys
import os

# Add src folder to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common.reader import create_sample_data
from common.validator import validate_not_null
from common.writer import log_output

from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

df = create_sample_data(spark)

df_clean = validate_not_null(df, "amount")

log_output(df_clean, "Silver")

print("Silver job completed")