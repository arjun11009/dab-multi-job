def validate_not_null(df, column):
    return df.filter(f"{column} IS NOT NULL")