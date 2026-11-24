
# Docker Initial Observations

**Project:** SEN421 — VM vs Docker  
**Date:** 2026-10-13  
**Environment:** Windows, Docker Desktop, WSL 2

## Initial Build

| Parameter | Value |
| --- | --- |
| Docker Image | `sen421-fastapi:1.0` |
| Image ID | `a0275bbd4d45` |
| Initial Build Duration | 90.6 seconds |
| Build Status | Successful |
| Image Size | 247107903 bytes (235.66 MiB) |

## Container

| Parameter | Value |
| --- | --- |
| Container Name | `sen421-fastapi-container` |
| Port Mapping | `127.0.0.1:8081:8081` |
| Container Startup | Successful |
| Container Stop | Successful |

## Resource Observation

| Metric | Observed Value |
| --- | --- |
| CPU Usage | 0.15% |
| Memory Usage | 37.48 MiB |
| Reported Memory Limit | 7.355 GiB |
| Processes/Tasks (PIDS) | 6 |

## Important Notes

- These values are preliminary observations and not final benchmark results.
- The build duration includes downloading and installing dependencies. It must not be interpreted as container startup time.
- Memory usage was observed at one point in time without a controlled workload.
- Further measurements will be repeated under controlled conditions.
