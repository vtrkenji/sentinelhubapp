# How to create test release archives for auto-update testing

This file explains how to prepare `.tar.gz` (Linux) and `.zip` (Windows) test artifacts containing your app's release folder so you can validate the in-app auto-update flow implemented in `lib/screens/update/update_screen.dart`.

Notes
- The app update scripts expect the archive to contain the app files (executable and related folders). If the archive has a single top-level folder, the update script will detect that and copy the CONTENTS of that folder into the application directory.
- Test locally first; the scripts run `cp -r` (Linux) or PowerShell `Copy-Item` (Windows).

1) Build your release binary / app bundle

Linux (example):
- Build your Linux release executable (depends on your packaging process). For a Flutter desktop release you may have a folder like `build/linux/x64/release/bundle/` containing the executable and resources.

Windows (example):
- Prepare the folder that contains the `.exe` and assets.

2) Create a `.tar.gz` for Linux testing

From the parent folder of your app bundle folder:

```bash
# Suppose your bundle folder is `myapp_bundle/` containing the executable
tar -czf sentinel_update_test.tar.gz myapp_bundle/
# Move the archive to a reachable HTTP server or upload to GitHub Releases
```

Important: The script in the app will extract and if it finds a single top-level folder (`myapp_bundle/`) it will copy the contents of that folder into the app directory (correct behavior).

3) Create a `.zip` for Windows testing

From the parent folder of your app folder:

```powershell
# In PowerShell
Compress-Archive -Path .\myapp_bundle\* -DestinationPath .\sentinel_update_test.zip -Force
```

Or using `zip` on Linux/macOS to create a zip:

```bash
zip -r sentinel_update_test.zip myapp_bundle/
```

4) Upload the test asset

- Create a GitHub Release (draft is fine) and upload the generated `sentinel_update_test.tar.gz` or `sentinel_update_test.zip` as an asset.
- Note the `browser_download_url` returned by the GitHub Releases API.

5) Point the running app to the test release

- The app `UpdateScreen` picks the first matching asset from the `releases/latest` API. You can:
  - Upload only one appropriate asset (e.g. `.tar.gz` for Linux) so the app selects it automatically, or
  - Modify `lib/screens/update/update_screen.dart` temporarily to set `_downloadUrl` to the direct asset URL (for testing only).

6) Run the update flow

- Start the app on the target platform (Linux or Windows). Open the Update screen and click `Baixar e Instalar`.
- Expected behavior on Linux:
  - The app downloads the `.tar.gz` to a temp dir.
  - The app writes `update.sh` which extracts, detects single top-level folder, copies contents into the application directory, marks the executable as executable, starts the new exe, and self-deletes.
- Expected behavior on Windows:
  - The app downloads the `.zip` to a temp dir.
  - The app writes `update.ps1` which extracts, detects a single top-level folder, copies the contents into the application directory using `Copy-Item`, starts the new `.exe`, and self-deletes.

7) Troubleshooting

- Permissions: Ensure the running user has permission to overwrite the app directory.
- Antivirus / SmartScreen (Windows): may block running newly copied executables when testing locally.
- If the app process cannot be overwritten while running, ensure the update script spawns the new executable from outside the original process and exits the old process (the scripts already try to `Start-Process` / run the new exe and `exit(0)`).

8) Safety

- These update scripts overwrite the app directory — use with care in production. For production use prefer atomic updater strategies (installers, package managers, or platform-specific update tools).

---
If you want, I can:
- Create a sample release archive from the current local `build/` folder (if you provide which bundle to package), or
- Attempt to create and push a git tag + draft GitHub Release and upload the test asset (requires repository write permissions / authentication).