from src.common.reader import create_sample_data
from src.common.writer import log_output


df = create_sample_data(spark)

log_output(df, "Bronze")

print("Bronze job completed")