$ErrorActionPreference = 'Stop'

$systemDirectory = Join-Path $env:SystemRoot 'System32'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $systemDirectory = Join-Path $env:SystemRoot 'Sysnative'
}

$gpupdate = Join-Path $systemDirectory 'gpupdate.exe'
if (-not (Test-Path -LiteralPath $gpupdate -PathType Leaf)) {
    Write-Output "Unable to detect LocalGPO status: gpupdate.exe was not found at '$gpupdate'."
    exit 0
}

try {
    $gpupdateOutput = (& $gpupdate /target:computer /force /wait:60 2>&1 | Out-String)
}
catch {
    Write-Output "Unable to run gpupdate; remediation was not triggered. $($_.Exception.Message)"
    exit 0
}

$hasLocalGpo = $gpupdateOutput -match '(?i)\bLocalGPO\b'
$hasProcessingError = $gpupdateOutput -match '(?i)(Fehler\s+bei\s+der\s+Verarbeitung\s+der\s+Gruppenrichtlinie|processing\s+of\s+Group\s+Policy\s+failed|failed\s+to\s+process\s+(?:the\s+)?Group\s+Policy|Group\s+Policy\s+processing\s+failed)'
$hasRegistryPolicySettings = $gpupdateOutput -match '(?i)(registrierungsbasierte\w*\s+Richtlinieneinstellungen|registry-based\s+policy\s+settings)'

if ($hasLocalGpo -and $hasProcessingError -and $hasRegistryPolicySettings) {
    Write-Output 'Detected the LocalGPO registry-based policy processing error. Remediation is required.'
    exit 1
}

Write-Output 'No matching LocalGPO registry-based policy processing error was detected.'
exit 0
