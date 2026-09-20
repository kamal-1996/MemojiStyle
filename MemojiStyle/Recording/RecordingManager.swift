import ARKit
import Combine
import Foundation

/// High-level recording orchestrator (Phase 10–12).
///
/// Wires the mic (`AudioManager`) to the frame writer (`SceneRecorder`), tracks
/// duration, resolves the achievable capture config, and saves to Photos on stop.
@MainActor
final class RecordingManager: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var statusMessage: String?
    @Published private(set) var activeConfig: CaptureConfiguration?

    private let audio = AudioManager()
    private let recorder = SceneRecorder()

    private weak var view: ARSCNView?
    private var currentURL: URL?
    private var timer: Timer?
    private var startDate: Date?

    init() {
        let recorder = self.recorder
        audio.onSampleBuffer = { sample in
            recorder.append(audio: sample)
        }
    }

    /// Called by the AR view once it exists so we can snapshot it.
    func attach(view: ARSCNView) {
        self.view = view
    }

    func toggle(quality: VideoQuality, micEnabled: Bool) {
        isRecording ? stop() : start(quality: quality, micEnabled: micEnabled)
    }

    func start(quality: VideoQuality, micEnabled: Bool) {
        guard !isRecording, let view = view else { return }

        let config = CaptureConfiguration.resolve(
            requested: quality,
            micEnabled: micEnabled,
            thermalState: ProcessInfo.processInfo.thermalState
        )
        activeConfig = config

        let url = VideoExportManager.makeOutputURL()
        currentURL = url

        if micEnabled {
            audio.configure()
            audio.start()
        }

        guard recorder.start(view: view, config: config, url: url) else {
            statusMessage = "Could not start recording"
            return
        }

        isRecording = true
        duration = 0
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in self.duration = Date().timeIntervalSince(start) }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate(); timer = nil
        audio.stop()

        recorder.stop { [weak self] url in
            guard let self else { return }
            guard let url = url else {
                self.statusMessage = "Recording failed"
                return
            }
            PhotoLibraryManager.save(url) { result in
                switch result {
                case .saved:
                    self.statusMessage = "Video saved"
                case .denied:
                    self.statusMessage = "Photos permission denied"
                case .failed(let message):
                    self.statusMessage = "Save failed: \(message)"
                }
                VideoExportManager.cleanUp(url)
            }
        }
    }
}
