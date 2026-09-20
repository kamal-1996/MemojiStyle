import ARKit
import AVFoundation
import UIKit

/// Chosen video quality (render resolution of the avatar scene).
enum VideoQuality: String, CaseIterable, Identifiable {
    case uhd4K = "4K"
    case fullHD = "1080p"
    case hd = "720p"

    var id: String { rawValue }

    var pixelSize: CGSize {
        switch self {
        case .uhd4K:  return CGSize(width: 3840, height: 2160)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .hd:     return CGSize(width: 1280, height: 720)
        }
    }
}

/// Resolves the ACTUAL, achievable recording configuration for this device
/// (Phase 11) and reports it honestly.
///
/// Important truth: ARKit's front TrueDepth *face-tracking* pipeline does not
/// offer a 4K camera feed. So while we can *render* the avatar at up to 4K, the
/// live camera background is limited to the AR video format (often 1080p/60 or
/// 720p/60). We never claim a resolution/fps we aren't actually using.
struct CaptureConfiguration {
    let renderSize: CGSize
    let fps: Int
    /// H.264 or HEVC (HEVC preferred where supported for smaller 4K files).
    let codec: AVVideoCodecType
    let hasAudio: Bool
    /// The AR camera feed format actually in use (for the camera background).
    let arCameraResolution: CGSize
    let arCameraFPS: Int

    var summary: String {
        let codecName = (codec == .hevc) ? "HEVC" : "H.264"
        return """
        Resolution: \(Int(renderSize.width))x\(Int(renderSize.height))
        FPS: \(fps)
        Codec: \(codecName)
        Audio: \(hasAudio ? "On (AAC)" : "Off")
        AR camera feed: \(Int(arCameraResolution.width))x\(Int(arCameraResolution.height)) @ \(arCameraFPS)
        """
    }

    /// Builds the best stable config for the requested quality + mic setting,
    /// falling back gracefully when the device/thermals can't sustain it.
    static func resolve(requested quality: VideoQuality,
                        micEnabled: Bool,
                        thermalState: ProcessInfo.ThermalState) -> CaptureConfiguration {

        // AR camera feed capability (limits the live background, not the render).
        let arFormat = FaceTrackingConfigurationFactory.bestVideoFormat()
        let arRes = arFormat.map { CGSize(width: $0.imageResolution.width,
                                          height: $0.imageResolution.height) } ?? CGSize(width: 1280, height: 720)
        let arFPS = arFormat?.framesPerSecond ?? 30

        // Thermal-aware downgrade of the render target.
        var effectiveQuality = quality
        switch thermalState {
        case .serious:
            if effectiveQuality == .uhd4K { effectiveQuality = .fullHD }
        case .critical:
            effectiveQuality = .hd
        default:
            break
        }

        // Target 60 fps only if the AR feed supports it; otherwise match it.
        let targetFPS = min(arFPS, 60)

        // HEVC for 4K/1080p when hardware supports it; else H.264.
        let codec: AVVideoCodecType = supportsHEVC() ? .hevc : .h264

        return CaptureConfiguration(
            renderSize: effectiveQuality.pixelSize,
            fps: targetFPS,
            codec: codec,
            hasAudio: micEnabled,
            arCameraResolution: arRes,
            arCameraFPS: arFPS
        )
    }

    private static func supportsHEVC() -> Bool {
        let props: [AVOutputSettingsPreset] = [.hevc1920x1080, .hevc3840x2160]
        return props.contains {
            AVOutputSettingsAssistant(preset: $0) != nil
        }
    }
}
