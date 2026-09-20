import SwiftUI

/// Final main screen (Phase 15). Extremely simple: avatar fills the screen,
/// a status pill on top, an optional debug readout, a record button, and a
/// settings sheet. No accounts, feeds, or sharing.
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if appState.isFaceTrackingSupported {
                AvatarSceneView(appState: appState)
                    .ignoresSafeArea()
            } else {
                UnsupportedView()
            }

            VStack {
                HStack(alignment: .top) {
                    StatusBadge(status: appState.trackingStatus)
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                }

                if appState.showDebug {
                    DebugView(performance: appState.performance,
                              fps: appState.fps,
                              config: appState.recording.activeConfig)
                        .padding(.top, 6)
                }

                Spacer()

                RecordingControls(recording: appState.recording) {
                    appState.toggleRecording()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
        .statusBarHidden(true)
    }
}

/// Top status pill.
struct StatusBadge: View {
    let status: TrackingStatus

    private var color: Color {
        switch status {
        case .active: return .green
        case .searching: return .orange
        case .unsupported: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(status.label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule())
    }
}

/// Shown when hardware has no TrueDepth camera.
private struct UnsupportedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Face tracking not supported")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text("This app needs an iPhone/iPad with a TrueDepth (Face ID) front camera.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    MainView().environmentObject(AppState())
}
