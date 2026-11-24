
from locust import HttpUser, task, between


class BenchmarkUser(HttpUser):
    wait_time = between(1, 2)

    @task(1)
    def health_check(self):
        self.client.get("/health", name="/health")

    @task(1)
    def get_items(self):
        self.client.get("/items", name="/items")

    @task(1)
    def compute(self):
        self.client.get("/compute", name="/compute")
