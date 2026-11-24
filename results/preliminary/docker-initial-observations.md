\# Docker Initial Observations



\*\*Project:\*\* SEN421 — VM vs Docker  

\*\*Date:\*\* 2026-10-13  

\*\*Environment:\*\* Windows, Docker Desktop, WSL 2



\## Initial Build



\- Docker image: `sen421-fastapi:1.0`

\- Image ID: `a0275bbd4d45`

\- Initial build duration: 90.6 seconds

\- Build status: Successful

\- Image size: 247107903 bytes (235.66 MiB)



\## Container



\- Container name: `sen421-fastapi-container`

\- Port mapping: `127.0.0.1:8081:8081`

\- Container startup: Successful

\- Container stopped successfully



\## Resource Observation



\- CPU usage: 0.15%

\- Memory usage: 37.48 MiB

\- Reported memory limit: 7.355 GiB

\- Processes/tasks (PIDS): 6



\## Important Notes



These values are preliminary observations and not final benchmark results.



The build duration includes downloading and installing dependencies. It must not be interpreted as container startup time.



Memory usage was observed at one point in time without a controlled workload.



Further measurements will be repeated under controlled conditions.

