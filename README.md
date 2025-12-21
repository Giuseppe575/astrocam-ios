# AstroCam

AstroCam is a SwiftUI + AVFoundation camera app inspired by ProCam, focused on manual control for astrophotography.

## Features
- Full-screen live preview
- Manual controls: ISO, shutter (0.1–30s), focus (0–1 + INF button), WB auto + Kelvin (3200–5000)
- AE/AF lock toggles
- RAW capture when supported, otherwise HEIF
- Intervalometer (N shots, interval, countdown, stop)
- Saves into custom album "AstroCam"
- Presets: Stelle, Via Lattea urbano (stacking), Via Lattea buio

## Requirements
- Xcode 15+
- iOS 16+
- Physical device (camera APIs are not available in the simulator)

## Build & Run
1. Open `AstroCam.xcodeproj` in Xcode.
2. Select a real iOS device as the run target.
3. In the target settings, set your Signing Team and Bundle Identifier.
4. Build and run.

## Permissions
AstroCam needs:
- Camera access for live preview and captures.
- Photo Library add access to save shots in the "AstroCam" album.

## Notes
- Long shutter speeds require a steady mount.
- RAW output depends on device support.

## Structure
- `AstroCam/` SwiftUI views and camera logic
- `AstroCam.xcodeproj/` Xcode project

