
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
$OutputDir = Join-Path $ProjectRoot "results\resources\vm"

$SshKey = Join-Path $env:USERPROFILE ".ssh\sen421_vm_ed25519"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# ----------------------------------------
# Output files
# ----------------------------------------

$ExperimentName = "vm_high_run$Run"
$Prefix = Join-Path $OutputDir $ExperimentName

$ResourceCsv = "${Prefix}_resources.csv"
$LocustPrefix = "${Prefix}_locust"

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
# Prerequisites
# ----------------------------------------

if (-not (Test-Path $Python)) {
    throw "Python executable not found: $Python"
}

if (-not (Test-Path $LocustFile)) {
    throw "Locust file not found: $LocustFile"
}

if (-not (Test-Path $SshKey)) {
    throw "SSH key not found: $SshKey"
}

$VmHost = "127.0.0.1"
$VmSshPort = 2222
$VmUser = "sen421"
$ApiUrl = "http://127.0.0.1:8083"

$SshArguments = @(
    "-i", $SshKey,
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=5",
    "-p", "$VmSshPort",
    "${VmUser}@${VmHost}"
)

# ----------------------------------------
# Remote resource collection
# ----------------------------------------

$RemoteCommand = @'
vmstat -n 1 2 | tail -n 1; free -k | grep '^Mem:'; ps -eo pid,rss,args --no-headers | grep '[p]ython -m uvicorn app.main:app' | head -n 1
'@

# ----------------------------------------
# Benchmark configuration
# ----------------------------------------

$Users = 30
$SpawnRate = 5
$Duration = "60s"

$LocustArguments = @(
    "-m", "locust",
    "-f", $LocustFile,
    "--headless",
    "--host", $ApiUrl,
    "--users", "$Users",
    "--spawn-rate", "$SpawnRate",
    "--run-time", $Duration,
    "--only-summary",
    "--csv", $LocustPrefix
)

# ----------------------------------------
# Create Locust process
# ----------------------------------------

$Process = New-Object System.Diagnostics.Process

$Process.StartInfo.FileName = $Python
$Process.StartInfo.UseShellExecute = $false

$QuotedArguments = foreach ($Argument in $LocustArguments) {
    '"' + $Argument.Replace('"', '\"') + '"'
}

$Process.StartInfo.Arguments = $QuotedArguments -join " "

# ----------------------------------------
# Monitoring
# ----------------------------------------

$Samples = New-Object 'System.Collections.Generic.List[object]'

Write-Host "====================================="
Write-Host "SEN421 VM RESOURCE BENCHMARK"
Write-Host "====================================="
Write-Host "Run: $Run"
Write-Host "Users: $Users"
Write-Host "Spawn rate: $SpawnRate users/s"
Write-Host "Duration: $Duration"
Write-Host "Target: $ApiUrl"
Write-Host "VM: $VmUser@$VmHost"
Write-Host "====================================="

# Check SSH before starting Locust.
$SshCheck = & ssh @SshArguments "echo SSH_OK"

if ($LASTEXITCODE -ne 0 -or $SshCheck.Trim() -ne "SSH_OK") {
    throw "SSH connection to VM failed."
}

Write-Host "SSH connection verified."

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
    Write-Host "Collecting VM CPU, RAM and FastAPI RSS..."

    while (-not $Process.HasExited) {

        $Raw = @(& ssh @SshArguments $RemoteCommand)

        if ($LASTEXITCODE -ne 0 -or $Raw.Count -ne 3) {
            throw "VM resource collection failed: $($Raw -join ' | ')"
        }

        # vmstat columns:
        # r b swpd free buff cache si so bi bo in cs us sy id wa st gu
        $VmstatFields = @(
            $Raw[0].Trim() -split '\s+'
        )

        if ($VmstatFields.Count -lt 17) {
            throw "Unexpected vmstat output: $($Raw[0])"
        }

        $CpuIdle = [double]::Parse(
            $VmstatFields[14],
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $CpuUsage = 100.0 - $CpuIdle

        # free -k columns:
        # Mem: total used free shared buff/cache available
        $MemoryFields = @(
            $Raw[1].Trim() -split '\s+'
        )

        if ($MemoryFields.Count -lt 7 -or $MemoryFields[0] -ne "Mem:") {
            throw "Unexpected memory output: $($Raw[1])"
        }

        $TotalKiB = [double]::Parse(
            $MemoryFields[1],
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $AvailableKiB = [double]::Parse(
            $MemoryFields[6],
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $UsedKiB = $TotalKiB - $AvailableKiB

        # ps columns: PID RSS COMMAND
        $ProcessFields = @(
            $Raw[2].Trim() -split '\s+'
        )

        if ($ProcessFields.Count -lt 3) {
            throw "Unexpected FastAPI process output: $($Raw[2])"
        }

        $RssKiB = [double]::Parse(
            $ProcessFields[1],
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $Now = Get-Date

        $Samples.Add(
            [pscustomobject]@{
                timestamp = $Now.ToString("o")

                elapsed_seconds = [math]::Round(
                    ($Now - $StartTime).TotalSeconds, 2
                )

                vm_cpu_percent = [math]::Round(
                    $CpuUsage, 2
                )

                vm_used_memory_mib = [math]::Round(
                    $UsedKiB / 1024.0, 2
                )

                vm_available_memory_mib = [math]::Round(
                    $AvailableKiB / 1024.0, 2
                )

                fastapi_rss_mib = [math]::Round(
                    $RssKiB / 1024.0, 2
                )
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
Write-Host "VM resource benchmark completed."
Write-Host "Locust exit code: $ExitCode"
Write-Host "Samples collected: $($Samples.Count)"
Write-Host "Resource CSV: $ResourceCsv"
Write-Host "Locust CSV prefix: $LocustPrefix"
Write-Host "====================================="
