import Foundation
import Combine

/// Simple tracking states surfaced to the UI in Phase 1.
enum TrackingStatus: Equatable {
    /// The device has no TrueDepth camera / ARFaceTrackingConfiguration unsupported.
    case unsupported
    /// Session running but no face currently detected.
    case searching
    /// A face is being tracked right now.
    case active

    var label: String {
        switch self {
        case .unsupported: return "Face tracking not supported on this device"
        case .searching:   return "Face not detected"
        case .active:      return "Face tracking active"
        }
    }
}

/// Shared, observable app state + owner of all subsystems.
///
/// Holds the tracking, avatar, recording and performance managers, plus the
/// user-facing settings. Views observe this object; the render loop reads the
/// settings each frame.
@MainActor
final class AppState: ObservableObject {

    // MARK: Subsystems
    let faceTracking = FaceTrackingManager()
    let avatarManager = AvatarManager.bundledOrProcedural()
    let recording = RecordingManager()
    let performance = PerformanceMonitor()

    // MARK: UI-mirrored tracking readouts
    @Published var trackingStatus: TrackingStatus = .searching
    @Published var fps: Double = 0

    // MARK: Settings (Phase 15)
    @Published var expressionStrength: Float = 1.0   // 0.2 ... 2.0
    @Published var hairEnabled: Bool = true
    @Published var mirrored: Bool = true
    @Published var backgroundMode: BackgroundMode = .camera
    @Published var videoQuality: VideoQuality = .fullHD
    @Published var micEnabled: Bool = true
    @Published var showDebug: Bool = true

    let isFaceTrackingSupported: Bool = FaceTrackingSupport.isSupported

    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Mirror tracking status + FPS into published UI properties.
        faceTracking.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.trackingStatus = $0 }
            .store(in: &cancellables)

        faceTracking.$fps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.fps = $0 }
            .store(in: &cancellables)

        performance.start()
    }

    // MARK: Recording passthrough
    func toggleRecording() {
        recording.toggle(quality: videoQuality, micEnabled: micEnabled)
    }
}
