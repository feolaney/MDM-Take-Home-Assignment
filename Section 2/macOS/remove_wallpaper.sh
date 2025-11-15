#!/bin/bash
# remove-wallpaper-all-users.sh
# Reverses changes made by set-wallpaper-all-users.sh:
# - Unloads and removes the LaunchAgent for active GUI users
# - Removes the LaunchAgent plist
# - Removes the per-user helper
# - Removes the managed wallpaper image(s)
#
# Usage: sudo ./remove-wallpaper-all-users.sh
# Notes:
# - Does not attempt to restore any user's prior wallpaper choice.
# - If an MDM profile enforces wallpaper, that policy will still win.

set -euo pipefail

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# No arguments expected
if [[ "$#" -ne 0 ]]; then
  fail "this script takes no arguments"
fi

# Root required
if [[ "${EUID}" -ne 0 ]]; then
  fail "run as root"
fi

LAUNCH_AGENT_LABEL="com.coursera.setwallpaper"
LAUNCH_AGENT_PLIST="/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"
HELPER="/usr/local/bin/set-wallpaper-user.sh"
DEST_DIR="/Library/Desktop Pictures"
IMG_BASENAME="ManagedWallpaper"
EXTS=(jpg jpeg png heic)

# Identify all active GUI user UIDs by locating loginwindow processes
get_gui_uids() {
  /bin/ps -A -o uid,comm | /usr/bin/awk '$2=="loginwindow"{print $1}' | /usr/bin/sort -u
}

# 1) Unload the LaunchAgent from active GUI sessions (if any)
UIDS="$(get_gui_uids || true)"
if [[ -n "${UIDS}" ]]; then
  log "unloading LaunchAgent for active GUI users"
  while IFS= read -r uid; do
    [[ -z "${uid}" ]] && continue
    # Try bootout using the plist path; ignore errors if not loaded
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_AGENT_PLIST}" 2>/dev/null || true
    # Some systems accept label targets; try that too
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_AGENT_LABEL}" 2>/dev/null || true
  done <<< "${UIDS}"
else
  log "no active GUI user sessions detected"
fi

# 2) Remove the LaunchAgent file
if [[ -f "${LAUNCH_AGENT_PLIST}" ]]; then
  rm -f "${LAUNCH_AGENT_PLIST}" || fail "failed to remove ${LAUNCH_AGENT_PLIST}"
  log "removed ${LAUNCH_AGENT_PLIST}"
else
  log "LaunchAgent plist not present; nothing to remove"
fi

# 3) Remove the helper script
if [[ -f "${HELPER}" ]]; then
  rm -f "${HELPER}" || fail "failed to remove ${HELPER}"
  log "removed ${HELPER}"
else
  log "helper not present; nothing to remove"
fi

# 4) Remove the managed wallpaper image(s)
FOUND_IMG=0
for ext in "${EXTS[@]}"; do
  path="${DEST_DIR}/${IMG_BASENAME}.${ext}"
  if [[ -f "${path}" ]]; then
    rm -f "${path}" || fail "failed to remove ${path}"
    log "removed ${path}"
    FOUND_IMG=1
  fi
done
if [[ "${FOUND_IMG}" -eq 0 ]]; then
  log "no managed wallpaper images found under ${DEST_DIR}"
fi

# 5) Clean up temp logs if present
for f in "/tmp/${LAUNCH_AGENT_LABEL}.out" "/tmp/${LAUNCH_AGENT_LABEL}.err"; do
  [[ -f "$f" ]] && { rm -f "$f" || warn "could not remove $f"; }
done

log "done. launch agent removed and unloaded; helper and managed image(s) deleted."
log "users keep their current desktop image until they change it or policy enforces a new one."
exit 0