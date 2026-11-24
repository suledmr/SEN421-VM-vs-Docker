from pathlib import Path
import csv
import statistics

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = PROJECT_ROOT / "results" / "experiments"


def read_experiment(environment, load, run):
    file_path = (
        RESULTS_DIR
        / environment
        / f"{environment}_{load}_run{run}_stats.csv"
    )

    with file_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)

        for row in reader:
            if row["Name"] == "Aggregated":
                return {
                    "requests": int(row["Request Count"]),
                    "failures": int(row["Failure Count"]),
                    "latency": float(row["Average Response Time"]),
                    "rps": float(row["Requests/s"]),
                    "p95": float(row["95%"]),
                }

    raise ValueError(f"Aggregated row not found: {file_path}")


def summarize(values):
    mean = statistics.mean(values)
    std = statistics.stdev(values)
    return mean, std


for environment in ["docker", "vm"]:
    for load in ["low", "high"]:
        runs = [
            read_experiment(environment, load, run)
            for run in [1, 2, 3]
        ]

        latencies = [run["latency"] for run in runs]
        rps_values = [run["rps"] for run in runs]
        p95_values = [run["p95"] for run in runs]

        latency_mean, latency_std = summarize(latencies)
        rps_mean, rps_std = summarize(rps_values)
        p95_mean, p95_std = summarize(p95_values)

        total_requests = sum(run["requests"] for run in runs)
        total_failures = sum(run["failures"] for run in runs)

        print(f"\nEnvironment: {environment.upper()}")
        print(f"Load: {load.upper()}")
        print(f"Total Requests: {total_requests}")
        print(f"Total Failures: {total_failures}")
        print(f"Latency: {latency_mean:.3f} ± {latency_std:.3f} ms")
        print(f"RPS: {rps_mean:.3f} ± {rps_std:.3f}")
        print(f"P95: {p95_mean:.3f} ± {p95_std:.3f} ms")