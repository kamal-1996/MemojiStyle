import ARKit
import Combine
import CoreVideo

/// Owns the ARKit face-tracking session and turns raw ARKit callbacks into our
/// device-independent `FaceTrackingData` stream.
///
/// Responsibilities (Phase 2):
///  - Own the `ARSession`.
///  - Start/stop `ARFaceTrackingConfiguration`.
///  - Receive `ARFaceAnchor` updates and publish `FaceTrackingData`.
///  - Expose the latest camera pixel buffer for the background layer.
///  - Publish tracking status + FPS for the UI.
///
/// Nothing here knows about avatars, rendering, or recording.
final class FaceTrackingManager: NSObject, ObservableObject {

    // MARK: Published streams

    /// Emits one value per tracked frame. Avatar layer subscribes to this.
    let dataPublisher = PassthroughSubject<FaceTrackingData, Never>()

    @Published private(set) var status: TrackingStatus = .searching
    @Published private(set) var fps: Double = 0

    /// Most recent camera image (for camera-background mode). Read on render loop.
    private(set) var latestPixelBuffer: CVPixelBuffer?

    /// The most recent tracking data (polled by the render loop for hair inertia).
    private(set) var latest: FaceTrackingData = .idle

    let session = ARSession()

    private var smoothedFPS: Double = 0
    private var lastTimestamp: TimeInterval = 0

    override init() {
        super.init()
        if !FaceTrackingSupport.isSupported {
            status = .unsupported
        }
    }

    // MARK: Lifecycle

    func start() {
        guard FaceTrackingSupport.isSupported else {
            status = .unsupported
            return
        }
        let config = FaceTrackingConfigurationFactory.make()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }
}

// MARK: - Ingestion (called by the ARSCNView coordinator)

extension FaceTrackingManager {

    /// Feed a tracked face anchor from the ARSCNView delegate.
    func ingest(faceAnchor: ARFaceAnchor, timestamp: TimeInterval) {
        let data = FaceTrackingData(anchor: faceAnchor, timestamp: timestamp)
        latest = data
        dataPublisher.send(data)
        setStatus(faceAnchor.isTracked ? .active : .searching)
    }

    /// No face is currently tracked.
    func markNoFace() {
        latest = .idle
        dataPublisher.send(.idle)
        setStatus(.searching)
    }

    /// Keeps FPS + camera buffer fresh. Call from `session(_:didUpdate frame:)`.
    func noteFrame(_ frame: ARFrame) {
        latestPixelBuffer = frame.capturedImage
        updateFPS(timestamp: frame.timestamp)
    }

    private func setStatus(_ newStatus: TrackingStatus) {
        guard status != newStatus else { return }
        DispatchQueue.main.async { [weak self] in
            self?.status = newStatus
        }
    }

    private func updateFPS(timestamp: TimeInterval) {
        defer { lastTimestamp = timestamp }
        guard lastTimestamp > 0 else { return }
        let delta = timestamp - lastTimestamp
        guard delta > 0 else { return }
        let instantaneous = 1.0 / delta
        smoothedFPS = smoothedFPS == 0 ? instantaneous : smoothedFPS * 0.9 + instantaneous * 0.1
        let value = smoothedFPS
        DispatchQueue.main.async { [weak self] in
            self?.fps = value
        }
    }
}
