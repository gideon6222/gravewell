# Gravewell

Cut down through a dead world toward its core, with only your lamp for light, then run for the surface with the core aboard.

A phone game for Android built in Godot 4.7. Every push to `main` builds a signed APK and
attaches it to a GitHub Release; tap the latest release on the phone to install or update.
A `v*` tag builds the Play bundle.

```powershell
scripts\check.ps1                                   # tests, smoke, guards
& $env:GODOT --headless --path . --export-debug "Android" build/gravewell.apk
scripts\device.ps1 install                          # onto the phone over adb
```

Built with Claude Code from `C:\dev\godot-template`, on the process in
`C:\dev\gamedev-notes`. Assets are credited in `assets/CREDITS.md`.
