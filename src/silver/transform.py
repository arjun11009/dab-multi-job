from src.common.reader import create_sample_data
from src.common.validator import validate_not_null
from src.common.writer import log_output


df = create_sample_data(spark)

df_clean = validate_not_null(df, "amount")

log_output(df_clean, "Silver")

print("Silver job completed")