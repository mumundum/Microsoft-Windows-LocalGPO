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
if (-not (Test-Path -LiteralPath $groupPolicyPath -PathType Container)) {
    Write-Error "Error: No GroupPolicy folder was found at '$groupPolicyPath'; nothing was removed."
    exit 0
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Error: Administrator privileges are required to remove the GroupPolicy folder.'
    exit 1
}

$folder = Get-Item -LiteralPath $groupPolicyPath -Force
if (($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Write-Error "Error: Refusing to remove '$groupPolicyPath' because it is a reparse point."
    exit 1
}

try {
    Remove-Item -LiteralPath $groupPolicyPath -Recurse -Force
}
catch {
    Write-Error "Error: Failed to remove '$groupPolicyPath': $($_.Exception.Message)"
    exit 1
}

if (Test-Path -LiteralPath $groupPolicyPath) {
    Write-Error "Error: The GroupPolicy folder still exists at '$groupPolicyPath' after removal."
    exit 1
}

Write-Output "Remediate: Removed '$groupPolicyPath'. Local Group Policy settings have been reset."
exit 0
