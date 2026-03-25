def log_output(df, label):
    print(f"{label} count: {df.count()}")
    df.show()