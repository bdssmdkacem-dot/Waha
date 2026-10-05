# Waha

Isometric impossible-geometry puzzle for Android (Godot 4.3). Original art, levels and sounds, all generated in code.

## Content
- Menu with level select and saved progress
- Stage 1 "The Folded Bridge": crank + folding bridge
- Stage 2 "The Turning Tower": stairs, sliding platform, rotating tower
- Oasis goal, dust and confetti particles, procedural sound effects, fade transitions

## Run locally
Open `project.godot` with Godot 4.3+, press F5.

## Build the APK on GitHub
Push this folder to a repo (branch `main`). The workflow `.github/workflows/build-android.yml` builds `waha.apk` and uploads it as the `waha-apk` artifact (Actions tab).

## Next steps
- Add levels in `levels.gd` (cells, edges, mechs)
- Play Store: switch to a release keystore + AAB (gradle build) in `export_presets.cfg`
- `UNLOCK_ALL` in `main.gd` unlocks every stage for testing
