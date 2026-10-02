[CmdletBinding()]
param(
    [string]$Profile = "flutter-observability-lab",
    [switch]$DeleteCluster
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
    $arguments = @("-e", "bash", "./scripts/k8s-down.sh", "--profile", $Profile)
    if ($DeleteCluster) {
        $arguments += "--delete"
    }
    & wsl.exe $arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Operacao no WSL falhou com exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
