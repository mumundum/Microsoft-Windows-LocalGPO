<#
.SYNOPSIS
Removes the LocalGPO GroupPolicy folder to reset Local Group Policy settings.

Usage: Use this script as the "Remediation script" paired with Detect-LocalGPOProcessingError.ps1 in Intune Remediations. Run in 64-bit PowerShell as SYSTEM.
Return: exits with code 0 on success and code 1 if remediation fails.
#>

$ErrorActionPreference = 'Stop'

$systemDirectory = Join-Path $env:SystemRoot 'System32'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $systemDirectory = Join-Path $env:SystemRoot 'Sysnative'
}

$groupPolicyPath = Join-Path $systemDirectory 'GroupPolicy'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Error: Administrator privileges are required to remove the GroupPolicy folder.' -ErrorAction Continue
    exit 1
}

if (Test-Path -LiteralPath $groupPolicyPath -PathType Container) {
    $folder = Get-Item -LiteralPath $groupPolicyPath -Force
    if (($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        Write-Error "Error: Refusing to remove '$groupPolicyPath' because it is a reparse point." -ErrorAction Continue
        exit 1
    }

    try {
        Remove-Item -LiteralPath $groupPolicyPath -Recurse -Force
    }
    catch {
        Write-Error "Error: Failed to remove '$groupPolicyPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 1
    }

    if (Test-Path -LiteralPath $groupPolicyPath) {
        Write-Error "Error: The GroupPolicy folder still exists at '$groupPolicyPath' after removal." -ErrorAction Continue
        exit 1
    }

    Write-Output "Remediate: Removed '$groupPolicyPath'."
}
else {
    Write-Output "Remediate: No GroupPolicy folder was found at '$groupPolicyPath'; verifying the policy refresh anyway."
}

$gpupdate = Join-Path $systemDirectory 'gpupdate.exe'
if (-not (Test-Path -LiteralPath $gpupdate -PathType Leaf)) {
    Write-Error "Error: Cannot verify remediation because gpupdate.exe was not found at '$gpupdate'." -ErrorAction Continue
    exit 1
}

$gpupdateStartedAt = Get-Date
try {
    $gpupdateOutput = (& $gpupdate /target:computer /force /wait:60 2>&1 | Out-String)
}
catch {
    Write-Error "Error: The GroupPolicy folder was removed, but gpupdate could not verify remediation. $($_.Exception.Message)" -ErrorAction Continue
    exit 1
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
    Write-Output 'gpupdate verification output:'
    Write-Output $gpupdateOutput.Trim()
    if ($matchingEvent) {
        Write-Output "Matching '$($matchingEvent.LogName)' event $($matchingEvent.Id) at $($matchingEvent.TimeCreated):"
        Write-Output $matchingEvent.Message
    }
    Write-Error 'Error: The LocalGPO processing error still occurs after remediation. Further investigation is required.' -ErrorAction Continue
    exit 1
}

Write-Output 'Remediate: The GroupPolicy folder was reset and gpupdate no longer reports the LocalGPO registry-policy error.'
exit 0
