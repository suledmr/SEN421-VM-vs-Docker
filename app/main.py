
from fastapi import FastAPI

app = FastAPI(
    title="SEN421 VM vs Docker Benchmark API",
    version="1.0.0"
)


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "sen421-benchmark"
    }


@app.get("/items")
def get_items():
    items = [
        {"id": 1, "name": "Laptop", "price": 25000},
        {"id": 2, "name": "Mouse", "price": 500},
        {"id": 3, "name": "Keyboard", "price": 1200}
    ]

    return {
        "count": len(items),
        "items": items
    }


@app.get("/compute")
def compute():
    total = 0

    for i in range(100000):
        total += i * i

    return {
        "result": total,
        "iterations": 100000
    }
