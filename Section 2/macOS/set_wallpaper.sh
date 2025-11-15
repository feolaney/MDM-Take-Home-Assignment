#!/bin/bash
# set-wallpaper-all-users.sh
# Usage: sudo ./set-wallpaper-all-users.sh
# Copies the image to /Library/Desktop Pictures/ManagedWallpaper.<ext>
# Installs a LaunchAgent that sets wallpaper for every user session at login.
# Applies immediately to the current console user if present.

set -euo pipefail

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -ne 0 ]]; then
  fail "run as root"
fi

# Hard-coded source image location; adjust here if the managed asset ever moves.
IMG_SRC="/private/var/tmp/img/romibackground.jpg"
if [[ ! -f "${IMG_SRC}" ]]; then
  fail "image not found: ${IMG_SRC}"
fi

EXT="$(basename -- "${IMG_SRC##*.}")"
EXT_LC="$(printf '%s' "${EXT}" | tr '[:upper:]' '[:lower:]')"
case "${EXT_LC}" in
  jpg|jpeg|png|heic) ;;
  *) fail "unsupported image type: ${EXT}";;
esac

DEST_DIR="/Library/Desktop Pictures"
DEST_PATH="${DEST_DIR}/ManagedWallpaper.${EXT_LC}"

# Ensure destination directory exists with sane permissions; stock macOS usually has
# it, but DEP images may omit it.
if [[ ! -d "${DEST_DIR}" ]]; then
  install -d -m 0755 -o root -g wheel "${DEST_DIR}" || fail "unable to create ${DEST_DIR}"
fi

# Copy image into a world readable system location
install -m 0644 -o root -g wheel "${IMG_SRC}" "${DEST_PATH}" || fail "failed to copy image to ${DEST_PATH}"

# Helper that runs inside each user's GUI session
HELPER="/usr/local/bin/set-wallpaper-user.sh"
# Ensure helper destination directory exists (clean installs may lack /usr/local/bin)
HELPER_DIR="$(dirname "${HELPER}")"
if [[ ! -d "${HELPER_DIR}" ]]; then
  install -d -m 0755 -o root -g wheel "${HELPER_DIR}" || fail "unable to create ${HELPER_DIR}"
fi
cat > "${HELPER}" <<'EOF'
#!/bin/zsh
set -euo pipefail
IMAGE_PATH="${1:-}"
if [[ -z "${IMAGE_PATH}" || ! -f "${IMAGE_PATH}" ]]; then
  print -u2 "missing or invalid image path: ${IMAGE_PATH}"
  exit 10
fi
# Use System Events to set all desktops across all displays
/usr/bin/osascript -e 'on run argv
  set p to POSIX file (item 1 of argv)
  tell application "System Events"
    repeat with d in desktops
      set picture of d to p
    end repeat
  end tell
end run' "${IMAGE_PATH}"
EOF
chmod 755 "${HELPER}"

# LaunchAgent that applies the wallpaper on every GUI login
PLIST="/Library/LaunchAgents/com.coursera.setwallpaper.plist"
cat > "${PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>com.coursera.setwallpaper</string>
    <key>ProgramArguments</key>
    <array>
      <string>${HELPER}</string>
      <string>${DEST_PATH}</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>StandardOutPath</key><string>/tmp/com.coursera.setwallpaper.out</string>
    <key>StandardErrorPath</key><string>/tmp/com.coursera.setwallpaper.err</string>
  </dict>
</plist>
PLIST
chown root:wheel "${PLIST}"
chmod 644 "${PLIST}"

# Apply immediately for the active console user, if any
CONSOLE_USER="$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && $3 != "loginwindow"{print $3}')"
if [[ -n "${CONSOLE_USER}" ]]; then
  UID_NUM="$(/usr/bin/id -u "${CONSOLE_USER}")" || UID_NUM=""
  if [[ -n "${UID_NUM}" ]]; then
    /bin/launchctl bootstrap "gui/${UID_NUM}" "${PLIST}" 2>/dev/null || true
    /bin/launchctl kickstart -k "gui/${UID_NUM}/com.coursera.setwallpaper" 2>/dev/null || true
    /bin/launchctl asuser "${UID_NUM}" "${HELPER}" "${DEST_PATH}" 2>/dev/null || true
  fi
fi

log "wallpaper set to ${DEST_PATH}; LaunchAgent installed for all users"
exit 0
