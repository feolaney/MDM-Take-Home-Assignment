
This document covers:
- Packaging the Chrome MSI into a `.intunewin`
- The tools used and where to download them
- Creating the Win32 app in Intune with correct install/uninstall commands
- Verifying install/uninstall locally using the same commands Intune would run
- Log locations and common return codes

---

## 1) Prerequisites
- **Google Chrome Enterprise MSI (x64)**
  Source example:
  `C:\Users\USERHOMEFOLDER\Desktop\GoogleChromeEnterpriseBundle64\Installers\GoogleChromeStandaloneEnterprise64.msi`
- **Pre-built Intune package (optional)**
  Download the ready-to-upload `.intunewin` from the shared drive mentioned in Section 1’s README: https://drive.google.com/drive/folders/16FeKeqFVWYCnqXAhFIdoN0_xmzk2-FiU?usp=drive_link
- **Microsoft Win32 Content Prep Tool**
  Example path:
  `C:\Users\USERHOMEFOLDER\Downloads\Microsoft-Win32-Content-Prep-Tool-1.8.7\Microsoft-Win32-Content-Prep-Tool-1.8.7\IntuneWinAppUtil.exe`
- **Optional for local SYSTEM-context testing**
  - PsExec (Sysinternals) to launch a SYSTEM shell

> Keep the content prep tool outside the source folder so it doesn’t get packed into your app.
> Example paths in this guide use `USERHOMEFOLDER` as a placeholder; replace it with the actual profile folder on your packaging workstation.

---

## 2) Where to download the tools
- **Chrome Enterprise MSI**
  Search for: “Chrome Enterprise MSI download” on the official Chrome Enterprise site.
- **Microsoft Win32 Content Prep Tool**
  Search for: “Microsoft Win32 Content Prep Tool GitHub” on the official Microsoft repository.
- **PsExec (optional)**
  Search for: “PsExec Sysinternals” on the official Microsoft site.
*(Exact URLs aren’t pinned here; use the official sources named above.)*

---

## 3) Create the Intune `.intunewin` package

Example folders:
- Source folder: `C:\Users\USERHOMEFOLDER\Desktop\GoogleChromeEnterpriseBundle64\Installers`
- Source file: `GoogleChromeStandaloneEnterprise64.msi`
- Output folder: `C:\Users\USERHOMEFOLDER\Desktop\IntunePackages\Chrome`
**Commands (CMD):**
```cmd
mkdir "C:\Users\USERHOMEFOLDER\Desktop\IntunePackages\Chrome"

"C:\Users\USERHOMEFOLDER\Downloads\Microsoft-Win32-Content-Prep-Tool-1.8.7\Microsoft-Win32-Content-Prep-Tool-1.8.7\IntuneWinAppUtil.exe" ^
  -c "C:\Users\USERHOMEFOLDER\Desktop\GoogleChromeEnterpriseBundle64\Installers" ^
  -s "GoogleChromeStandaloneEnterprise64.msi" ^
  -o "C:\Users\USERHOMEFOLDER\Desktop\IntunePackages\Chrome" ^
  -q
````

Result:

C:\Users\USERHOMEFOLDER\Desktop\IntunePackages\Chrome\GoogleChromeStandaloneEnterprise64.intunewin

---

## 4) Create the Win32 app in Intune
**Intune Admin Center**

Apps -> Windows -> Add -> App type: Windows app (Win32) -> Select the .intunewin you created.

### 4.1 Program commands

Use **one** of the following variants for each command pair (with or without verbose logging).

#### Install command
- **Without verbose logging**

```
msiexec.exe /i "GoogleChromeStandaloneEnterprise64.msi" /qn /norestart
```
- **With verbose logging**

```
msiexec.exe /i "GoogleChromeStandaloneEnterprise64.msi" /qn /norestart /L*V "C:\Windows\Temp\Chrome_Install.log"
```

#### Uninstall command

Replace the GUID with your actual ProductCode. Provided example:

{17373029-5456-3C3A-B8DA-86A6C6E057E0}
- **Without verbose logging**

```
msiexec.exe /x {17373029-5456-3C3A-B8DA-86A6C6E057E0} /qn /norestart
```
- **With verbose logging**

```
msiexec.exe /x {17373029-5456-3C3A-B8DA-86A6C6E057E0} /qn /norestart /L*V "C:\Windows\Temp\Chrome_Uninstall.log"
```

> Notes
- > /qn is silent. /norestart avoids forced reboot.
- > Treat return code 0 or 3010 as successful (3010 = success with restart required).

### 4.2 Detection rules
- **MSI detection**: When you upload an MSI-based .intunewin, Intune can auto-populate the ProductCode. Prefer MSI detection for reliability.

### 4.3 Requirements and assignments
- Requirements: Architecture x64, minimum OS as needed.
- Assignments: Required or Available for enrolled devices as appropriate.

---

## 5) Test locally in SYSTEM context

Intune runs Win32 apps as **SYSTEM** via the Intune Management Extension. Testing as your admin user isn’t equivalent.

### Option A: PsExec (recommended)

1. Launch a SYSTEM CMD:

```
psexec.exe -i -s cmd.exe
```

2. Install silently with verbose log:

```
msiexec.exe /i "C:\Users\USERHOMEFOLDER\Desktop\GoogleChromeEnterpriseBundle64\Installers\GoogleChromeStandaloneEnterprise64.msi" /qn /norestart /L*V "C:\Windows\Temp\Chrome_Install.log"
```

3. Uninstall silently with verbose log:

```
msiexec.exe /x {17373029-5456-3C3A-B8DA-86A6C6E057E0} /qn /norestart /L*V "C:\Windows\Temp\Chrome_Uninstall.log"
```

### Option B: Task Scheduler (if PsExec is blocked)

Create a one-time SYSTEM task:

```
schtasks /Create /TN "TestChromeInstall" /TR "msiexec.exe /i \"C:\Users\USERHOMEFOLDER\Desktop\GoogleChromeEnterpriseBundle64\Installers\GoogleChromeStandaloneEnterprise64.msi\" /qn /norestart /L*V \"C:\Windows\Temp\Chrome_Install.log\"" /SC ONCE /ST 00:00 /RL HIGHEST /RU "SYSTEM"
schtasks /Run /TN "TestChromeInstall"
```

Delete the task after testing.

---

## 6) Verify installation and uninstallation

### 6.1 Check via registry for MSI presence and ProductCode
**PowerShell:**

```
$paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'

Get-ItemProperty $paths |
  Where-Object { $_.DisplayName -eq 'Google Chrome' -and $_.WindowsInstaller -eq 1 } |
  Select-Object DisplayName, DisplayVersion, PSChildName
```
- PSChildName is the ProductCode GUID for the MSI.

### 6.2 Check Chrome version by file

```
(Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo
```

### 6.3 Quick presence test

```
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 6.4 Event Viewer MSI entries
- Application log, source MsiInstaller
- Success install event ID 11707
- Success uninstall event ID 11724

---

## 7) Log locations
- **Your explicit MSI logs**
    - C:\Windows\Temp\Chrome_Install.log
    - C:\Windows\Temp\Chrome_Uninstall.log
- **Intune Management Extension logs** (when deployed via Intune)
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\
    - IntuneManagementExtension.log
    - AppWorkload.log
    - AppActionProcessor.log
    - AgentExecutor.log
- **Windows Event Viewer**
    Application log -> Source MsiInstaller

---

## 8) Common return codes
- 0 success
- 3010 success, restart required
- 1603 fatal error during installation
- 1618 another installation already in progress

Handle 3010 as success in your deployment status, with a restart handled by separate policy if needed.

---

## 9) Appendix — Helpful one-liners
**Find Chrome MSI ProductCode GUID**

```
$k='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
(Get-ItemProperty $k | Where-Object { $_.DisplayName -eq 'Google Chrome' -and $_.WindowsInstaller -eq 1 } | Select-Object -First 1 -ExpandProperty PSChildName)
```
**Silent uninstall using resolved GUID**

```
$k='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
$guid = (Get-ItemProperty $k | Where-Object { $_.DisplayName -eq 'Google Chrome' -and $_.WindowsInstaller -eq 1 } | Select-Object -First 1 -ExpandProperty PSChildName)
if($guid){ Start-Process msiexec.exe -ArgumentList "/x",$guid,"/qn","/norestart" -Wait -NoNewWindow } else { exit 1 }
```
**Force-close Chrome prior to uninstall (best effort)**

```
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

## 10) Quick checklist
- Package created with IntuneWinAppUtil from the MSI
- MSI install/uninstall commands set, with or without verbose logging
- MSI detection rule populated by ProductCode
- Assignments configured
- Local SYSTEM-context test passes
- Logs verified in C:\Windows\Temp and IME logs if using Intune
