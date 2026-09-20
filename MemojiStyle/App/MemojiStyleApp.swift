import SwiftUI
import UIKit

/// App entry point.
///
/// Runs the full pipeline: front TrueDepth camera → ARKit face tracking →
/// device-independent tracking model → avatar rig + hair → SceneKit render →
/// record (video + mic) → save to Photos. All processing stays on-device.
@main
struct MemojiStyleApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                // Keep the screen awake while the user is talking to the camera.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}
