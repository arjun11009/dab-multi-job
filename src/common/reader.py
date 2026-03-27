
def create_sample_data(spark):
    data = [
        (1, "Alice", 100),
        (2, "Bob", None),
        (3, "Charlie", 300)
    ]
    print("will this fucntion work")
    return spark.createDataFrame(data, ["id", "name", "amount"])