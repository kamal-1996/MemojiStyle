import ARKit
import SceneKit
import UIKit

/// Background modes (Phase 9).
enum BackgroundMode: String, CaseIterable, Identifiable {
    case camera        // live front-camera feed (ARSCNView default)
    case solid         // solid color
    case transparent   // clear (useful if you later composite in an editor)

    var id: String { rawValue }
    var label: String {
        switch self {
        case .camera: return "Camera"
        case .solid: return "Solid color"
        case .transparent: return "Transparent"
        }
    }
}

/// Applies the chosen background to an `ARSCNView`.
///
/// Honest note: `ARSCNView` renders the AR camera feed itself. For `.solid` /
/// `.transparent` we override `scene.background.contents`; for `.camera` we clear
/// that override so the camera feed shows through. Exact behavior can vary by iOS
/// version — verify on device and adjust if needed.
enum BackgroundController {

    static func apply(_ mode: BackgroundMode, to view: ARSCNView, color: UIColor = .black) {
        switch mode {
        case .camera:
            view.scene.background.contents = nil
            view.backgroundColor = .clear
        case .solid:
            view.scene.background.contents = color
            view.backgroundColor = color
        case .transparent:
            view.scene.background.contents = UIColor.clear
            view.backgroundColor = .clear
        }
    }
}
