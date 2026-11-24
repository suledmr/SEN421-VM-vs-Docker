
param(
    [ValidateRange(1, 3600)]
    [int]$DurationSeconds = 70,

    [ValidateRange(1, 60)]
    [int]$IntervalSeconds = 2,

    [string]$OutputFile = "results/docker_resource_test.csv"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath = Join-Path $ProjectRoot $OutputFile
$OutputDirectory = Split-Path -Parent $OutputPath

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if (Test-Path $OutputPath) {
    throw "Output file already exists: $OutputPath"
}

$ContainerName = "sen421-fastapi-container"
$Samples = [System.Collections.Generic.List[object]]::new()

Write-Host "Monitoring container: $ContainerName"
Write-Host "Duration: $DurationSeconds seconds"
Write-Host "Interval: $IntervalSeconds seconds"

$Timer = [System.Diagnostics.Stopwatch]::StartNew()

while ($Timer.Elapsed.TotalSeconds -lt $DurationSeconds) {
    $Timestamp = (Get-Date).ToString("o")

    $Raw = docker stats --no-stream --format `
        "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" `
        $ContainerName

    if ($LASTEXITCODE -ne 0 -or -not $Raw) {
        throw "Failed to collect Docker statistics."
    }

    $Fields = $Raw.Trim() -split "\|"

    if ($Fields.Count -ne 3) {
        throw "Unexpected Docker statistics format: $Raw"
    }

    $Samples.Add([pscustomobject]@{
        timestamp = $Timestamp
        elapsed_seconds = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
        cpu_percent = $Fields[0].Trim().TrimEnd("%")
        memory_usage = $Fields[1].Trim()
        memory_percent = $Fields[2].Trim().TrimEnd("%")
    })

    Start-Sleep -Seconds $IntervalSeconds
}

$Samples | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Monitoring completed."
Write-Host "Samples collected: $($Samples.Count)"
Write-Host "Saved to: $OutputPath"
