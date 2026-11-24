
param(
    [ValidateRange(1, 3)]
    [int]$Run = 1
)

$ErrorActionPreference = "Stop"

# ----------------------------------------
# Project paths
# ----------------------------------------

$ProjectRoot = Split-Path -Parent $PSScriptRoot

$Python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$LocustFile = Join-Path $ProjectRoot "tests\locustfile.py"

$OutputDir = Join-Path $ProjectRoot "results\resources\docker"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# ----------------------------------------
# Output files
# ----------------------------------------

$ExperimentName = "docker_high_run$Run"

$Prefix = Join-Path $OutputDir $ExperimentName

$ResourceCsv = "${Prefix}_resources.csv"
$LocustPrefix = "${Prefix}_locust"

# Protect existing results
if (Test-Path $ResourceCsv) {
    throw "Resource results already exist: $ResourceCsv"
}

$ExistingLocustFiles = @(
    Get-ChildItem -Path $OutputDir `
        -Filter "${ExperimentName}_locust*.csv"
)

if ($ExistingLocustFiles.Count -gt 0) {
    throw "Locust results already exist for run $Run"
}

# ----------------------------------------
# Validate prerequisites
# ----------------------------------------

if (-not (Test-Path $Python)) {
    throw "Python executable not found: $Python"
}

if (-not (Test-Path $LocustFile)) {
    throw "Locust file not found: $LocustFile"
}

$Container = "sen421-fastapi-container"

$ContainerId = docker inspect `
    --format "{{.Id}}" $Container 2>$null

if ($LASTEXITCODE -ne 0 -or -not $ContainerId) {
    throw "Docker container not found: $Container"
}

$ContainerState = docker inspect `
    --format "{{.State.Running}}" $Container

if ($LASTEXITCODE -ne 0 -or $ContainerState.Trim() -ne "true") {
    throw "Docker container is not running: $Container"
}

# ----------------------------------------
# Benchmark configuration
# ----------------------------------------

$Users = 30
$SpawnRate = 5
$Duration = "60s"
$HostUrl = "http://127.0.0.1:8081"

$Arguments = @(
    "-m", "locust",
    "-f", $LocustFile,
    "--headless",
    "--host", $HostUrl,
    "--users", "$Users",
    "--spawn-rate", "$SpawnRate",
    "--run-time", $Duration,
    "--only-summary",
    "--csv", $LocustPrefix
)

# ----------------------------------------
# Create process (PowerShell 5.1 compatible)
# ----------------------------------------

$Process = New-Object System.Diagnostics.Process

$Process.StartInfo.FileName = $Python
$Process.StartInfo.UseShellExecute = $false

# PowerShell 5.1 / .NET Framework compatible
$QuotedArguments = foreach ($Argument in $Arguments) {
    '"' + $Argument.Replace('"', '\"') + '"'
}

$Process.StartInfo.Arguments = $QuotedArguments -join " "

# ----------------------------------------
# Resource monitoring
# ----------------------------------------

$Samples = New-Object 'System.Collections.Generic.List[object]'

Write-Host "====================================="
Write-Host "SEN421 DOCKER RESOURCE BENCHMARK"
Write-Host "====================================="
Write-Host "Run: $Run"
Write-Host "Users: $Users"
Write-Host "Spawn rate: $SpawnRate users/s"
Write-Host "Duration: $Duration"
Write-Host "Target: $HostUrl"
Write-Host "Container: $Container"
Write-Host "====================================="

$Started = $false
$ExitCode = $null
$StartTime = $null

try {
    $Started = $Process.Start()

    if (-not $Started) {
        throw "Locust process could not be started."
    }

    $StartTime = Get-Date

    Write-Host "Locust started."
    Write-Host "Collecting Docker CPU and RAM statistics..."

    while (-not $Process.HasExited) {

        $Raw = docker stats `
            --no-stream `
            --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" `
            $Container

        if ($LASTEXITCODE -ne 0 -or -not $Raw) {
            throw "Docker stats failed."
        }

        $Fields = $Raw.Trim() -split "\|"

        if ($Fields.Count -ne 3) {
            throw "Unexpected Docker stats output: $Raw"
        }

        $Now = Get-Date

        $Samples.Add(
            [pscustomobject]@{
                timestamp = $Now.ToString("o")

                elapsed_seconds = [math]::Round(
                    ($Now - $StartTime).TotalSeconds, 2
                )

                cpu_percent = $Fields[0].Trim().TrimEnd("%")

                memory_usage = $Fields[1].Trim()

                memory_percent = $Fields[2].Trim().TrimEnd("%")
            }
        )

        Start-Sleep -Seconds 2

        $Process.Refresh()
    }

    $Process.WaitForExit()

    $ExitCode = $Process.ExitCode
}
finally {

    if ($Started -and -not $Process.HasExited) {
        $Process.Kill()
        $Process.WaitForExit()
    }

    if ($Samples.Count -gt 0) {

        $Samples |
            Export-Csv `
                -Path $ResourceCsv `
                -NoTypeInformation `
                -Encoding UTF8

        Write-Host ""
        Write-Host "Resource samples saved: $($Samples.Count)"
        Write-Host "Resource CSV: $ResourceCsv"
    }

    $Process.Dispose()
}

# ----------------------------------------
# Validate benchmark result
# ----------------------------------------

if ($ExitCode -ne 0) {
    throw "Locust failed with exit code $ExitCode"
}

Write-Host ""
Write-Host "====================================="
Write-Host "Resource benchmark completed."
Write-Host "Locust exit code: $ExitCode"
Write-Host "Samples collected: $($Samples.Count)"
Write-Host "Resource CSV: $ResourceCsv"
Write-Host "Locust CSV prefix: $LocustPrefix"
Write-Host "====================================="
