\# Docker Containers vs Virtual Machines



SEN421 – Cloud Architecture and Services  

Fall 2026 – Topic 2, Part A



\## Project Overview



This project compares Docker containers and VirtualBox virtual machines using the same FastAPI application under controlled workloads.



The comparison focuses on response time, throughput, CPU usage, memory usage, startup time, storage footprint, and cost.



\## System Architecture



!\[System Architecture](docs/system\_architecture.png)



The application is deployed in two environments:



\- Docker Desktop with the WSL2 backend.

\- Ubuntu 24.04 running on Oracle VirtualBox 7.2.20.



\## Experimental Environment



| Component | Specification |

|---|---|

| Host OS | Windows 11 |

| Processor | AMD Ryzen 7 6800H |

| Host RAM | 16 GB |

| Storage | NVMe SSD |

| CPU allocation | 2 CPUs per environment |

| Memory allocation | 2 GiB per environment |

| Application | FastAPI |

| Load testing tool | Locust |

| Docker host port | 8081 |

| VM host port | 8083 |



\## Application Endpoints



| Endpoint | Description |

|---|---|

| `/health` | Returns application health status. |

| `/items` | Returns a predefined list of items. |

| `/compute` | Performs a calculation with 100,000 iterations. |



\## Project Structure



\- `app/` — FastAPI application.

\- `docker/` — Dockerfile.

\- `vm/` — Virtual machine service configuration.

\- `tests/` — Load testing and resource monitoring scripts.

\- `analysis/` — Python analysis script and Jupyter Notebook.

\- `docs/` — Architecture diagram and environment documentation.

\- `results/experiments/` — Raw performance measurements.

\- `results/resources/` — CPU and memory measurements.

\- `results/summaries/` — Aggregated experimental results.

\- `results/figures/` — Comparison charts.

\- `requirements.txt` — Application dependencies.

\- `requirements-lock.txt` — Dependency versions.



\## Benchmark Configuration



| Parameter | Low Load | High Load |

|---|---|---|

| Concurrent users | 5 | 30 |

| Spawn rate | 1 user/s | 5 users/s |

| Duration | 60 seconds | 60 seconds |

| Repetitions | 3 | 3 |

| Wait time | 1–2 seconds | 1–2 seconds |



All three application endpoints have equal task weights.



\## Prerequisites



\- Python 3.12

\- Docker Desktop with WSL2

\- Oracle VirtualBox

\- Ubuntu 24.04

\- Windows PowerShell

\- OpenSSH client

\- Locust

\- Jupyter Notebook



Create the local Python environment from the project root:



```powershell

python -m venv .venv

.\\.venv\\Scripts\\python.exe -m pip install -r requirements.txt

.\\.venv\\Scripts\\python.exe -m pip install locust pandas matplotlib notebook

```



\## Docker Deployment



Build the Docker image from the project root:



```powershell

docker build -f docker/Dockerfile -t sen421-fastapi:1.0 .

```



Create and start the container with the configured resource limits:



```powershell

docker run -d --name sen421-fastapi-container --cpus=2 --memory=2g -p 127.0.0.1:8081:8081 sen421-fastapi:1.0

```



Verify application availability:



```powershell

Invoke-RestMethod http://127.0.0.1:8081/health

```



\## Virtual Machine Deployment



Create an Ubuntu 24.04 virtual machine with the following configuration:



\- 2 virtual CPUs

\- 2 GiB RAM

\- 25 GB virtual disk

\- NAT networking



Configure VirtualBox NAT port forwarding:



| Service | Host IP | Host Port | Guest Port |

|---|---|---|---|

| FastAPI | 127.0.0.1 | 8083 | 8081 |

| SSH | 127.0.0.1 | 2222 | 22 |



The VM configuration assumes a Linux user named `sen421` and the application directory `/home/sen421/sen421-benchmark`.



Copy the `app/` directory, `requirements.txt`, and `vm/sen421-fastapi.service` into the VM project directory.



Install the required system packages:



```bash

sudo apt update

sudo apt install python3 python3-venv openssh-server

sudo systemctl enable --now ssh

```



Run the following commands from the VM project directory as the `sen421` user:



```bash

python3 -m venv .venv

.venv/bin/python -m pip install -r requirements.txt

```



Install and start the systemd service:



```bash

sudo cp vm/sen421-fastapi.service /etc/systemd/system/

sudo systemctl daemon-reload

sudo systemctl enable --now sen421-fastapi.service

sudo systemctl status sen421-fastapi.service

```



Verify application availability from the Windows host:



```powershell

Invoke-RestMethod http://127.0.0.1:8083/health

```



\## Benchmark Execution



The repository includes the original experimental results. Before repeating the experiments, back up and move the existing `results/experiments/` and `results/resources/` directories outside the project directory in a separate working copy.



The benchmark scripts prevent existing results from being overwritten.



Example performance benchmark commands:



```powershell

.\\tests\\run\_benchmark.ps1 -Environment docker -Load low -Run 1

.\\tests\\run\_benchmark.ps1 -Environment docker -Load high -Run 1

.\\tests\\run\_benchmark.ps1 -Environment vm -Load low -Run 1

.\\tests\\run\_benchmark.ps1 -Environment vm -Load high -Run 1

```



Repeat each configuration using run numbers 1, 2, and 3.



Performance measurements are saved under `results/experiments/`.



\## Resource Monitoring



\### Docker



The Docker resource benchmark collects container-level CPU and memory statistics using `docker stats` while Locust generates the high-load workload.



```powershell

.\\tests\\run\_resource\_benchmark.ps1 -Run 1

```



Repeat using run numbers 2 and 3.



\### Virtual Machine



The VM resource benchmark collects guest-level CPU and memory usage and FastAPI process RSS through SSH.



The monitoring commands used inside the VM are:



```bash

vmstat -n 1 2

free -k

ps -eo pid,rss,args

```



The script requires key-based SSH authentication using a locally generated SSH key located at:



`$env:USERPROFILE\\.ssh\\sen421\_vm\_ed25519`



Configure the corresponding public key in the VM before running the benchmark. Private SSH keys are not included in this repository.



Verify SSH connectivity:



```powershell

ssh -i "$env:USERPROFILE\\.ssh\\sen421\_vm\_ed25519" -p 2222 sen421@127.0.0.1

```



Run the VM resource benchmark:



```powershell

.\\tests\\run\_vm\_resource\_benchmark.ps1 -Run 1

```



Repeat using run numbers 2 and 3.



Both resource monitoring scripts include a two-second waiting period between collection cycles. Actual sampling intervals may vary due to command execution and SSH communication overhead.



Resource measurements are saved under `results/resources/`.



\## Data Analysis



Calculate performance statistics from the raw Locust CSV files:



```powershell

.\\.venv\\Scripts\\python.exe analysis/performance\_analysis.py

```



The script calculates the arithmetic mean and sample standard deviation across three repetitions.



To explore the analysis notebook, launch Jupyter:



```powershell

.\\.venv\\Scripts\\python.exe -m notebook

```



Open `analysis/benchmark\_analysis.ipynb` to review the experimental analysis and visualizations.



The original summary tables and comparison figures are available under `results/summaries/` and `results/figures/`.





\## Experimental Results



The raw measurements, summary tables, and comparison charts are available in the `results/` directory.



The analysis notebook is available at `analysis/benchmark\_analysis.ipynb`.



\## Limitations



The experiments were conducted on a single local computer using two workload levels. The observed throughput does not represent the maximum capacity of either environment.



Resource usage, startup time, and storage measurements have different measurement scopes and should therefore be interpreted with caution.



\## Academic Context



This repository contains the implementation, experimental data, configuration files, and supporting materials for an individual SEN421 course project.



AI assistance is disclosed in the accompanying project report.

