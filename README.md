# Intune Remediation: LocalGPO Processing Error

These Windows PowerShell 5.1 scripts detect and remediate a specific LocalGPO registry-based policy processing error. Deploy `Detect-LocalGPOProcessingError.ps1` as the Intune detection script and `Remediate-LocalGPOProcessingError.ps1` as its remediation script. Run both scripts in the 64-bit PowerShell host as SYSTEM.

## Detection

The detection script runs `gpupdate.exe /target:computer /force /wait:60` and reports a non-compliant result when its output contains all of the following:

- A LocalGPO reference.
- A registry-based policy settings reference.
- A group policy processing failure message.

It also checks for the same error in new Group Policy events in the Windows Application, System, and Group Policy Operational logs, which helps when the `gpupdate` message is localized or incomplete. Event messages are matched by their LocalGPO, registry-policy, and processing-failure text, rather than relying on a particular event ID. Exit code `1` requests remediation; exit code `0` indicates compliance or that a matching error could not be detected. If `gpupdate.exe` cannot be found or invoked, the script exits `0` so that remediation is not triggered.

## Remediation

The remediation script removes `%SystemRoot%\System32\GroupPolicy`, which resets the Local Group Policy settings stored below it, then runs `gpupdate` again to verify that the specific LocalGPO error is gone. It requires administrator privileges, refuses to remove reparse points, and verifies that the folder was removed. It reports remediation failure if the error is still present in the new `gpupdate` output or a new Group Policy event. If the folder is already absent, it still runs the verification refresh.

The script exits `0` when verification succeeds, and exits `1` for privilege, reparse-point, removal, or verification failures.

## Intune configuration

- Detection script: `Detect-LocalGPOProcessingError.ps1`
- Remediation script: `Remediate-LocalGPOProcessingError.ps1`
- Run scripts in 64-bit PowerShell: Enabled
- Run as: System
