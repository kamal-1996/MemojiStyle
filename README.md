# MemojiStyle — original Memoji-style avatar recorder (personal use)

Front TrueDepth camera → ARKit face tracking → your **original** 3D cartoon
avatar (facial expressions, gaze, head motion, secondary hair movement) →
record avatar + camera + mic → save to Photos. Everything runs **on-device**.
No accounts, no cloud, no server. **Not** using Apple's Memoji assets.

> You are on Windows. These Swift files can't compile here. Build & test on a
> Mac with Xcode on a **real Face ID iPhone**. This folder is the source you drag
> into an Xcode app target.

## Project layout

```
MemojiStyle/
  App/         MemojiStyleApp.swift, AppState.swift
  AR/          FaceTrackingSupport, FaceTrackingData, FaceTrackingConfiguration, FaceTrackingManager
  Avatar/      AvatarManager, AvatarController, AvatarFaceRig, AvatarSmoothing, RigDriver, ProceduralAvatar
  Animation/   EyeController, ExpressionController, HairMotionController
  Rendering/   AvatarSceneView, SceneLighting, BackgroundController
  Recording/   CaptureConfiguration, AudioManager, SceneRecorder, RecordingManager, VideoExportManager
  Photos/      PhotoLibraryManager
  Performance/ PerformanceMonitor
  UI/          MainView, RecordingControls, DebugView, SettingsView
```

## Create the Xcode project (Mac)

1. Xcode → **File ▸ New ▸ Project ▸ iOS ▸ App**. SwiftUI, Swift.
2. **Minimum Deployments = iOS 15.0**.
3. Delete the auto-generated `ContentView.swift` and default `App` struct.
4. Drag the `MemojiStyle/` folders in (Copy items if needed, create groups).
5. In target **Info**, add these usage strings (app crashes without them):
   - `NSCameraUsageDescription` — "Used to animate your avatar."
   - `NSMicrophoneUsageDescription` — "Used to record audio with your video."
   - `NSPhotoLibraryAddUsageDescription` — "Used to save your recordings."
6. Select your personal signing team.

## Run

- Real **Face ID iPhone** (iPhone X+; iPhone 12 Pro+ recommended for 60fps/4K
  render + hair physics headroom). The Simulator has no TrueDepth camera.
- Point it at your face, press the red button to record, press again to stop.
  The video saves to Photos.

## What each phase maps to

| Phase | Where |
|------|-------|
| 1 Face tracking | `AR/FaceTrackingManager`, `AvatarSceneView` |
| 2 Blendshapes | `AR/FaceTrackingData` |
| 3 Avatar architecture | `Avatar/AvatarManager`, `AvatarController`, `AvatarFaceRig`, `RigDriver` |
| 4 Custom avatar | `Avatar/ProceduralAvatar` (placeholder) + `AvatarManager.init(usdzURL:)` |
| 5 Facial animation quality | `Avatar/AvatarSmoothing`, `Animation/ExpressionController` |
| 6 Eye movement | `Animation/EyeController` |
| 7 Hair movement | `Animation/HairMotionController` |
| 8 Lighting/render | `Rendering/SceneLighting` |
| 9 Background | `Rendering/BackgroundController` |
| 10 Recording | `Recording/SceneRecorder`, `RecordingManager`, `AudioManager` |
| 11 4K/60 | `Recording/CaptureConfiguration` |
| 12 Save to Photos | `Photos/PhotoLibraryManager` |
| 13 Personal avatar input | see "Using your own avatar" below |
| 14 Performance | `Performance/PerformanceMonitor` |
| 15 Final UI | `UI/*` |

## Using your own rigged avatar (Phase 4 / 13)

The app ships a simple **procedural** placeholder so the whole pipeline runs
with no binary asset. To use a real character:

1. Author an original 3D head in Blender/Maya with **ARKit-compatible
   blendshapes** (the ~52 standard shapes), eye/jaw bones, and hair bones.
   Export `CustomAvatar.usdz` into `Resources/Avatar/`.
2. Build an `AvatarFaceRig` whose `morphTargetNames` map each `AvatarChannel`
   to your model's blendshape target names.
3. In `AppState`, replace `AvatarManager()` with
   `AvatarManager(usdzURL: <url>, rig: <rig>)`. Nothing else changes — the
   manager auto-selects `MorpherRigDriver` when it finds morph targets.

A single 2D reference photo is a **design reference only** — it cannot
automatically produce a production facial rig. Use it to guide modeling.

## Honest limitations (read these)

- **4K/60:** ARKit's front *face-tracking* camera has no 4K video format, so the
  live **camera background** is limited to the AR feed (often 1080p/60 or
  720p/60). The **avatar render** can target 4K; `CaptureConfiguration` reports
  the actual resolution/fps/codec and auto-downgrades under thermal pressure. It
  never claims a spec it isn't using.
- **Recording** snapshots the composited view each frame (simple + correct);
  at 4K on older devices this is heavy — the config falls back automatically.
  A/V sync uses the shared host clock; verify/tune on device.
- **Head axis mirroring** (`AvatarController.mirrored`) and the ARSCNView
  camera-background vs solid-color toggle may need small on-device sign/behavior
  tweaks depending on iOS version.
- No code here was runnable on Windows; the Mac/Xcode build is where you
  compile, test, and tune.
```
