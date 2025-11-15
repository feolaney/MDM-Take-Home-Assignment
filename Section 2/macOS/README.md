This document covers:
- Deploying a managed wallpaper to every macOS user session
- Files installed, where they live, and why they matter
- Rolling back the change with the provided removal script

---

## 1) Prerequisites
- **Source wallpaper file**
  Located at `/private/var/tmp/img/romibackground.jpg` (update `set_wallpaper.sh` if this ever moves).
- **Admin / root access**
  Run the script with `sudo` so it can copy files into `/Library` and manage LaunchAgents.
- **Automation approval**
  The helper uses `osascript` to drive System Events; the first run in each user session prompts for permission.

---

## 2) What the script does
`set_wallpaper.sh` bundles everything needed for a persistent wallpaper:
1. Validates the wallpaper (exists, supported extension) and copies it to `/Library/Desktop Pictures/ManagedWallpaper.<ext>`.
2. Emits `/usr/local/bin/set-wallpaper-user.sh`, a zsh helper that tells System Events to update every desktop space.
3. Installs `/Library/LaunchAgents/com.coursera.setwallpaper.plist` so each Aqua login runs the helper for that user.
4. Immediately bootstraps/kickstarts the LaunchAgent for the active console user so the wallpaper changes right away.
5. Writes logs to `/tmp/com.coursera.setwallpaper.(out|err)` to aid troubleshooting.

> Tip: If `/usr/local/bin` or `/Library/Desktop Pictures` is missing, the script creates them with sane permissions before writing files.

---

## 3) Usage
Example run (from within this folder):
```bash
sudo ./set_wallpaper.sh
```
- Re-run the script any time you update the source wallpaper file—existing files are overwritten in-place.
- Expect a one-time "System Events" automation prompt per user; selecting **Allow** lets future runs proceed silently.

---

## 4) Removing the configuration
Run `sudo ./remove_wallpaper.sh` to unload the LaunchAgent from active GUI sessions and delete the helper, plist, managed wallpaper image(s), and temp logs.
