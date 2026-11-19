# Intune Remediation: LocalGPO Processing Error

These Windows PowerShell 5.1 scripts detect and remediate a specific LocalGPO registry-based policy processing error. Deploy `Detect-LocalGPOProcessingError.ps1` as the Intune detection script and `Remediate-LocalGPOProcessingError.ps1` as its remediation script. Run both scripts in the 64-bit PowerShell host as SYSTEM.

## Detection

The detection script runs `gpupdate.exe /target:computer /force /wait:60` and reports a non-compliant result only when all of the following appear in its output:

- A LocalGPO reference.
- A registry-based policy settings reference.
- A group policy processing failure message.

It also recognizes a German processing-error message. Exit code `1` requests remediation; exit code `0` indicates compliance or that a matching error could not be detected. If `gpupdate.exe` cannot be found or invoked, the script exits `0` so that remediation is not triggered.

## Remediation

The remediation script removes `%SystemRoot%\System32\GroupPolicy`, which resets the Local Group Policy settings stored below it. It requires administrator privileges, refuses to remove reparse points, and verifies that the folder was removed.

The script exits `0` when the folder is removed successfully or no folder exists, and exits `1` for privilege, reparse-point, removal, or verification failures.

## Intune configuration

- Detection script: `Detect-LocalGPOProcessingError.ps1`
- Remediation script: `Remediate-LocalGPOProcessingError.ps1`
- Run scripts in 64-bit PowerShell: Enabled
- Run as: System
