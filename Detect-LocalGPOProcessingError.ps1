<#
.SYNOPSIS
Detects LocalGPO registry-based policy processing errors from gpupdate output.

Usage: Use this script as the "Detection script" paired with Remediate-LocalGPOProcessingError.ps1 in Intune Remediations. Run in 64-bit PowerShell as SYSTEM.
Return: exits with code 1 when the matching LocalGPO processing error is detected and code 0 otherwise.
#>

$ErrorActionPreference = 'Stop'

$systemDirectory = Join-Path $env:SystemRoot 'System32'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $systemDirectory = Join-Path $env:SystemRoot 'Sysnative'
}

$gpupdate = Join-Path $systemDirectory 'gpupdate.exe'
if (-not (Test-Path -LiteralPath $gpupdate -PathType Leaf)) {
    Write-Error "Error: Unable to detect LocalGPO status: gpupdate.exe was not found at '$gpupdate'." -ErrorAction Continue
    exit 0
}

$gpupdateStartedAt = Get-Date
try {
    $gpupdateOutput = (& $gpupdate /target:computer /force /wait:60 2>&1 | Out-String)
}
catch {
    Write-Error "Error: Unable to run gpupdate; remediation was not triggered. $($_.Exception.Message)" -ErrorAction Continue
    exit 0
}

function Test-LocalGpoProcessingError {
    param([string]$Text)

    return (
        $Text -match '(?i)\bLocalGPO\b' -and
        $Text -match '(?i)(registrierungsbasierte\w*\s+Richtlinieneinstellungen|registry-based\s+policy\s+settings)' -and
        $Text -match '(?i)(Fehler\s+bei\s+der\s+Verarbeitung\s+der\s+Gruppenrichtlinie|processing\s+of\s+Group\s+Policy\s+failed|failed\s+to\s+process\s+(?:the\s+)?Group\s+Policy|Group\s+Policy\s+processing\s+failed)'
    )
}

$matchingEvent = $null
$eventQueries = @(
    @{ LogName = 'Application'; ProviderName = 'GroupPolicy' }
    @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-GroupPolicy' }
    @{ LogName = 'Microsoft-Windows-GroupPolicy/Operational'; ProviderName = 'Microsoft-Windows-GroupPolicy' }
)
foreach ($eventQuery in $eventQueries) {
    try {
        $events = @(Get-WinEvent -FilterHashtable @{
            LogName = $eventQuery.LogName
            ProviderName = $eventQuery.ProviderName
            StartTime = $gpupdateStartedAt
        } -ErrorAction Stop)
        $matchingEvent = $events | Where-Object { Test-LocalGpoProcessingError -Text $_.Message } | Select-Object -First 1
        if ($matchingEvent) {
            break
        }
    }
    catch {
        if ($_.FullyQualifiedErrorId -notmatch '^NoMatchingEventsFound,') {
            Write-Warning "Unable to query '$($eventQuery.LogName)' events from '$($eventQuery.ProviderName)': $($_.Exception.Message)"
        }
    }
}

if ((Test-LocalGpoProcessingError -Text $gpupdateOutput) -or $matchingEvent) {
    if ($matchingEvent) {
        Write-Output "Non-compliant: LocalGPO registry-based policy processing error recorded in '$($matchingEvent.LogName)' event $($matchingEvent.Id) at $($matchingEvent.TimeCreated). Remediation is required."
    }
    else {
        Write-Output 'Non-compliant: LocalGPO registry-based policy processing error reported by gpupdate. Remediation is required.'
    }
    exit 1
}

Write-Output 'Compliant: No matching LocalGPO registry-based policy processing error was detected.'
exit 0
