
param(
    [ValidateSet("docker", "vm")]
    [string]$Environment = "docker",

    [ValidateSet("low", "high")]
    [string]$Load = "low",

    [ValidateRange(1, 3)]
    [int]$Run = 1
)

$ErrorActionPreference = "Stop"

# Project paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$LocustFile = Join-Path $ProjectRoot "tests\locustfile.py"

# Target environment
if ($Environment -eq "docker") {
    $HostUrl = "http://127.0.0.1:8081"
}
else {
    $HostUrl = "http://127.0.0.1:8083"
}

# Load configuration
if ($Load -eq "low") {
    $Users = 5
    $SpawnRate = 1
}
else {
    $Users = 30
    $SpawnRate = 5
}

$Duration = "60s"

# Output paths
$OutputDirectory = Join-Path $ProjectRoot "results\experiments\$Environment"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$ExperimentName = "${Environment}_${Load}_run${Run}"
$CsvPrefix = Join-Path $OutputDirectory $ExperimentName

# Protect existing results
$ExistingFiles = Get-ChildItem -Path $OutputDirectory -Filter "$ExperimentName*.csv"

if ($ExistingFiles.Count -gt 0) {
    throw "Results already exist for $ExperimentName. Choose another run number."
}

# Run benchmark
Write-Host "====================================="
Write-Host "SEN421 PERFORMANCE BENCHMARK"
Write-Host "====================================="
Write-Host "Environment: $Environment"
Write-Host "Load: $Load"
Write-Host "Run: $Run"
Write-Host "Users: $Users"
Write-Host "Spawn rate: $SpawnRate users/s"
Write-Host "Duration: $Duration"
Write-Host "Target: $HostUrl"
Write-Host "====================================="

& $Python -m locust `
    -f $LocustFile `
    --headless `
    --host $HostUrl `
    --users $Users `
    --spawn-rate $SpawnRate `
    --run-time $Duration `
    --only-summary `
    --csv $CsvPrefix

if ($LASTEXITCODE -ne 0) {
    throw "Locust failed with exit code $LASTEXITCODE"
}

Write-Host "Benchmark completed: $ExperimentName"
