This document covers:
- What `set_automatic_updates.ps1` configures
- Requirements to run it
- Example usage and optional parameters
- How to confirm policy is active and how to roll it back

---

## 1) Prerequisites
- **Elevated PowerShell session**
  The script writes to HKLM policy keys and manages the Windows Update service, so it must run in an Administrator PowerShell window.
- **Execution policy**
  If your environment restricts script execution, set `Set-ExecutionPolicy -Scope Process Bypass` for the current session.
- **Internet access (optional)**
  Only needed if you pass `-ScanNow`, which triggers an immediate Windows Update detection cycle.

---

## 2) What the script does
`set_automatic_updates.ps1` enforces a consistent Automatic Updates policy across the device:
1. Creates or updates `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`.
2. Sets `NoAutoUpdate=0` and `AUOptions=4` (Auto download + schedule install).
3. Applies the scheduled install day (`0` = every day, `1`–`7` = Sunday–Saturday) and `ScheduledInstallTime` (0–23) based on parameters.
4. Ensures the Windows Update service (`wuauserv`) is set to Manual and running.
5. Calls the Windows Update Agent COM interface to mirror the same settings, optionally triggering `DetectNow` when `-ScanNow` is present.
6. Reads the policy back for verification and prints the resulting schedule.

---

## 3) Usage
Default behavior (install every day at 3 AM):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\set_automatic_updates.ps1
```

Schedule Tuesday at 1 AM and kick off an immediate scan:

```powershell
.\set_automatic_updates.ps1 -InstallDay 3 -InstallTime 1 -ScanNow
```

- `-InstallDay` accepts 0–7; 0 means “every day.”
- `-InstallTime` is 0–23 (24-hour clock).
- `-ScanNow` is a switch to run `DetectNow` after policy application.

---

## 4) Verification
- **Registry**: Check `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` for `AUOptions=4`, expected day/time, and `NoAutoUpdate=0`.
- **Windows Update UI**: Settings → Windows Update should show automatic updates managed by the organization and reflect the scheduled install window.
- **Event Viewer**: `Microsoft-Windows-WindowsUpdateClient/Operational` logs will show policy evaluation and detection events after running with `-ScanNow`.

---

## 5) Rollback
1. Remove or change the policy values under `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`.
2. Optionally disable scheduled installs by setting `AUOptions=2` (notify download/install) or deleting the `AU` key entirely.
3. Use `gpupdate /force` (if joined to Azure AD/GPO) or simply wait for the next policy refresh to ensure the system reflects the change.

Without the policy key, Windows Update reverts to user-configurable behavior or whichever MDM/GPO setting takes precedence. 
