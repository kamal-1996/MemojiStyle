import ARKit

/// Builds and describes the ARKit face-tracking configuration.
///
/// Phase 11 note: ARKit's *front* face-tracking camera exposes a limited set of
/// `videoFormat`s (commonly 720p/1080p). True 4K capture is NOT offered by the
/// TrueDepth face-tracking pipeline, so we pick the best AR format available and
/// report it honestly. The avatar itself can still be *rendered* at higher
/// resolution — see `CaptureConfiguration`.
enum FaceTrackingConfigurationFactory {

    /// Creates a configuration using the highest-FPS supported video format.
    static func make(preferHighFrameRate: Bool = true) -> ARFaceTrackingConfiguration {
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        config.isLightEstimationEnabled = true

        if preferHighFrameRate, let best = bestVideoFormat() {
            config.videoFormat = best
        }
        return config
    }

    /// Highest framerate, then highest resolution, among supported AR formats.
    static func bestVideoFormat() -> ARConfiguration.VideoFormat? {
        ARFaceTrackingConfiguration.supportedVideoFormats.max { lhs, rhs in
            if lhs.framesPerSecond != rhs.framesPerSecond {
                return lhs.framesPerSecond < rhs.framesPerSecond
            }
            let lPixels = lhs.imageResolution.width * lhs.imageResolution.height
            let rPixels = rhs.imageResolution.width * rhs.imageResolution.height
            return lPixels < rPixels
        }
    }
}
