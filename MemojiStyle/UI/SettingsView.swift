import SwiftUI

/// Minimal settings (Phase 15). Only the knobs that matter for a personal
/// recording tool — no accounts, sync, or onboarding.
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Avatar & Expression") {
                    VStack(alignment: .leading) {
                        Text("Expression strength: \(String(format: "%.1f", appState.expressionStrength))")
                        Slider(value: $appState.expressionStrength, in: 0.2...2.0, step: 0.1)
                    }
                    Toggle("Mirror head movement", isOn: $appState.mirrored)
                    Toggle("Hair movement", isOn: $appState.hairEnabled)
                }

                Section("Background") {
                    Picker("Background", selection: $appState.backgroundMode) {
                        ForEach(BackgroundMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }

                Section("Recording") {
                    Picker("Video quality", selection: $appState.videoQuality) {
                        ForEach(VideoQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    Toggle("Microphone", isOn: $appState.micEnabled)
                    Text("Note: the live camera background is limited to the ARKit face-tracking feed. 4K applies to the rendered avatar; the app records the best stable configuration your device supports.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Developer") {
                    Toggle("Show debug overlay", isOn: $appState.showDebug)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView(appState: AppState())
}
