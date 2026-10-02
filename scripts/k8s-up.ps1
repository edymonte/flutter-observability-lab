[CmdletBinding()]
param(
    [string]$Profile = "flutter-observability-lab",
    [int]$Cpus = 4,
    [int]$MemoryMb = 6144
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
    wsl.exe -e bash ./scripts/k8s-up.sh --profile $Profile --cpus $Cpus --memory $MemoryMb
    if ($LASTEXITCODE -ne 0) {
        throw "Provisionamento no WSL falhou com exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
