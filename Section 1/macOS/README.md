This document covers:
- Packaging the Chrome macOS installer PKG inside a wrapper PKG using Composer
- The tools used and where to download them
- Creating the Jamf Pro policy and what the postinstall script does
- Verifying the install locally using the same command the MDM would run
- Log locations and common return codes

---

## 1) Prerequisites
- **Google Chrome for macOS PKG**
    Example source before packaging:
    /Users/USERHOMEFOLDER/Downloads/googlechrome.pkg
- **Pre-built wrapper (optional)**
    If you just need the finished installer, grab it from the shared drive referenced in Section 1’s README: https://drive.google.com/drive/folders/16FeKeqFVWYCnqXAhFIdoN0_xmzk2-FiU?usp=drive_link
- **Jamf Composer** to build the wrapper PKG
- **Administrative access** on a test Mac for local validation

> Keep the file name used by the postinstall consistent. The script below expects:

> /private/var/tmp/googlechrome/GoogleChrome.pkg

> If your source is lowercase, either rename it to GoogleChrome.pkg before packaging or update PKG_PATH in the script.
> Any sample path that references `USERHOMEFOLDER` is a placeholder—swap it for the actual home folder on the Mac you are packaging from.

---

## 2) Where to download the tools
- **Chrome for Enterprise PKG (macOS)**
    Search for “Chrome Enterprise download Mac PKG” on the official Chrome Enterprise site.
- **Composer**
    Available from your Jamf Pro account download page.

_(Exact URLs are intentionally not pinned. Use the official sources.)_

---

## 3) Build the wrapper PKG in Composer
**Goal**

Stage the vendor installer at /private/var/tmp/googlechrome/GoogleChrome.pkg, then have the wrapper’s postinstall run the vendor PKG silently with verbose, timestamped logging.
**Steps**

1. Open Composer and create a new package.
2. In the payload, add the following folder structure:
    private/var/tmp/googlechrome
3. Place the Chrome vendor PKG inside that folder and name it exactly:
    GoogleChrome.pkg
4. Set ownership and permissions on the staged PKG:
    - Owner root
    - Group wheel
    - Mode 0644
5. Add a **postinstall** script in the Scripts tab with executable permissions 0755. Use the script below.
6. Build as a flat package. Signing is optional but recommended in production.
**postinstall script**

```
#!/bin/sh
# Postinstall for Chrome wrapper: installs staged GoogleChrome.pkg with verbose, timestamped logging

set -u

PKG_PATH="/private/var/tmp/googlechrome/GoogleChrome.pkg"
TARGET="${1:-/}"
LOG_DIR="/var/logs"
LOG_FILE="${LOG_DIR}/chromeinstall.log"

# Exit codes
EXIT_SUCCESS=0
EXIT_NOT_ROOT=2
EXIT_LOG_SETUP_FAIL=3
EXIT_PKG_MISSING=4
EXIT_PIPE_FAIL=5

ts() { date "+%Y-%m-%d %H:%M:%S%z"; }

log_line() {
  printf "[%s] %s\n" "$(ts)" "$1" | tee -a "$LOG_FILE" >/dev/null
}

cleanup() {
  [ -n "${PIPE_PATH:-}" ] && [ -p "$PIPE_PATH" ] && rm -f "$PIPE_PATH"
}
trap cleanup EXIT INT TERM

# Root check
if [ "$(id -u)" -ne 0 ]; then
  echo "Must be run as root" >&2
  exit "$EXIT_NOT_ROOT"
fi

# Prepare logging
if ! mkdir -p "$LOG_DIR"; then
  echo "Failed to create log directory at $LOG_DIR" >&2
  exit "$EXIT_LOG_SETUP_FAIL"
fi
touch "$LOG_FILE" 2>/dev/null || {
  echo "Failed to create log file at $LOG_FILE" >&2
  exit "$EXIT_LOG_SETUP_FAIL"
}
chown root:wheel "$LOG_FILE" 2>/dev/null || true
chmod 0644 "$LOG_FILE" 2>/dev/null || true

log_line "Starting Google Chrome installation."
log_line "Source pkg: $PKG_PATH"
log_line "Target volume: $TARGET"

if [ ! -f "$PKG_PATH" ]; then
  log_line "Package not found at $PKG_PATH"
  exit "$EXIT_PKG_MISSING"
fi

# Timestamp the installer output using a FIFO
PIPE_PATH="$(mktemp -u /var/tmp/chrome_install_pipe.XXXXXX)"
if ! mkfifo "$PIPE_PATH"; then
  log_line "Failed to create logging pipe"
  exit "$EXIT_PIPE_FAIL"
fi

(
  while IFS= read -r line; do
    printf "[%s] %s\n" "$(ts)" "$line"
  done < "$PIPE_PATH"
) | tee -a "$LOG_FILE" >/dev/null &
LOGGER_PID=$!

/usr/sbin/installer -pkg "$PKG_PATH" -target "$TARGET" -verboseR -dumplog >"$PIPE_PATH" 2>&1
INSTALL_RC=$?

wait "$LOGGER_PID" 2>/dev/null || true

if [ "$INSTALL_RC" -eq 0 ]; then
  log_line "Google Chrome installation completed successfully."
  # Optional cleanup of staged installer:
  # rm -f "$PKG_PATH"
  exit "$EXIT_SUCCESS"
else
  log_line "Google Chrome installation failed with exit code $INSTALL_RC"
  exit "$INSTALL_RC"
fi
```
**Result**

A wrapper PKG that contains the vendor installer and runs it via postinstall, emitting verbose, timestamped logs to /var/logs/chromeinstall.log and also to /var/log/install.log through -dumplog.

---

## 4) Create the deployment in Jamf Pro
**Jamf Pro Admin Console**

Computers -> Policies -> New
- **General**
    - Trigger Recurring Check-in or Custom as needed
    - Execution Frequency Ongoing or Once per computer based on your rollout plan
- **Packages**
    - Add the wrapper PKG you built in Composer
    - No additional scripts are required in the policy because the postinstall inside the PKG performs the installation
- **Maintenance**
    - Optional, run inventory update after
- **Scope**
    - Target your test devices or Smart Groups
- **User Interaction**
    - None required. Install is silent.
**What Jamf runs**

Jamf installs your wrapper with installer -pkg <wrapper>.pkg -target /. The wrapper’s postinstall then runs the staged GoogleChrome.pkg and handles logging and exit codes.

---

## 5) Test locally using the same behavior as MDM

### Option A: Run the wrapper PKG directly

```
sudo /usr/sbin/installer -pkg "/path/to/YourChromeWrapper.pkg" -target /
```

### Option B: Validate the staged path and vendor PKG manually

After the wrapper has staged the file, you can re-run the vendor PKG invocation for troubleshooting:

```
sudo /usr/sbin/installer -pkg "/private/var/tmp/googlechrome/GoogleChrome.pkg" -target / -verboseR -dumplog
```

---

## 6) Verify installation

### 6.1 Check app presence

```
test -d "/Applications/Google Chrome.app" && echo "Chrome present" || echo "Chrome missing"
```

### 6.2 Check Chrome version

```
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/Google Chrome.app/Contents/Info.plist"
```

or

```
defaults read "/Applications/Google Chrome.app/Contents/Info" CFBundleShortVersionString
```

### 6.3 Check for receipts

```
pkgutil --pkgs | grep -i "com.google.Chrome"
pkgutil --pkg-info com.google.Chrome
```

### 6.4 Review logs

```
tail -n 100 /var/logs/chromeinstall.log
grep -i "chrome" /var/log/install.log | tail -n 50
```

---

## 7) Log locations
- **Wrapper postinstall log**
    - /var/logs/chromeinstall.log
        The script creates this directory if it does not exist and timestamps every line.
- **System installer log**
    - /var/log/install.log
        Populated by Apple’s installer when -dumplog is used.
- **Jamf client logs**
    - /var/log/jamf.log
        For policy execution context and package install status.

> If you prefer the standard /var/log path, change LOG_DIR="/var/log" in the script.

---

## 8) Common return codes
**From the wrapper’s postinstall**
- 0 success
- 2 script was not run as root
- 3 failed to create or prepare the log directory or file
- 4 staged PKG missing at /private/var/tmp/googlechrome/GoogleChrome.pkg
- 5 failed to create the temporary logging pipe
- Any other nonzero value is bubbled from /usr/sbin/installer and indicates a failure installing the vendor PKG
**Jamf behavior**

Jamf treats exit code 0 as success. Any nonzero exit code marks the policy run as a failure.

---

## 9) Appendix — Helpful one-liners
**Run the wrapper from the current directory**

```
sudo /usr/sbin/installer -pkg ./YourChromeWrapper.pkg -target /
```
**Follow the custom log in real time**

```
sudo tail -f /var/logs/chromeinstall.log
```
**Verify staged file before install**

```
ls -l /private/var/tmp/googlechrome/GoogleChrome.pkg
```
**Hash the vendor PKG to confirm integrity**

```
shasum -a 256 /private/var/tmp/googlechrome/GoogleChrome.pkg
```
**List all receipts that contain chrome**

```
pkgutil --pkgs | grep -i chrome
```
**Optional cleanup snippet for the postinstall success path**

```
# Add inside the success branch of the script if you want to reclaim disk space
rm -f "/private/var/tmp/googlechrome/GoogleChrome.pkg"
```

---

## 10) Quick checklist
- Chrome vendor PKG obtained from the official source
- Composer wrapper stages the file at /private/var/tmp/googlechrome/GoogleChrome.pkg
- Postinstall script added, executable, owned by root with group wheel
- Wrapper PKG built and uploaded to Jamf Pro
- Policy created and scoped
- Local test with installer -pkg <wrapper> -target / passes
- Logs validated in /var/logs/chromeinstall.log and /var/log/install.log
- Chrome present in /Applications and version verified
