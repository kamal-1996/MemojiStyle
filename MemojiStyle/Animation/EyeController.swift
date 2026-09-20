import SceneKit
import simd

/// Drives eye direction on the procedural avatar.
///
/// Aggregates ARKit's per-eye look coefficients into a left/right and up/down
/// gaze, smooths it, clamps to a physically reasonable cone, and rotates the
/// eye nodes. If the avatar has no eye nodes (e.g. a morpher-only model that
/// bakes gaze into blendshapes) this controller no-ops.
final class EyeController {
    private let eyeLeft: SCNNode?
    private let eyeRight: SCNNode?

    private var hSmoother = ScalarSmoother()
    private var vSmoother = ScalarSmoother()

    /// Maximum eye rotation from center (radians). ~17° is comfortable.
    private let maxYaw: Float = 0.30
    private let maxPitch: Float = 0.26

    init(eyeLeft: SCNNode?, eyeRight: SCNNode?) {
        self.eyeLeft = eyeLeft
        self.eyeRight = eyeRight
    }

    func update(channels: [AvatarChannel: Float], smoothing: Float) {
        func v(_ c: AvatarChannel) -> Float { channels[c] ?? 0 }

        // Horizontal: positive = look to the avatar's right (+X gaze).
        // ARKit "In" is toward the nose, "Out" is toward the ears.
        let leftEyeH  = v(.eyeLookOutLeft)  - v(.eyeLookInLeft)
        let rightEyeH = v(.eyeLookInRight)  - v(.eyeLookOutRight)
        let horizontal = (leftEyeH + rightEyeH) * 0.5

        let up   = (v(.eyeLookUpLeft)   + v(.eyeLookUpRight))   * 0.5
        let down = (v(.eyeLookDownLeft) + v(.eyeLookDownRight)) * 0.5
        let vertical = up - down

        let h = hSmoother.update(target: horizontal, smoothing: smoothing)
        let vv = vSmoother.update(target: vertical, smoothing: smoothing)

        let yaw = clamp(h, -1, 1) * maxYaw
        let pitch = clamp(vv, -1, 1) * maxPitch

        // Rotate eyeballs: pitch about X, yaw about Y.
        let euler = SCNVector3(pitch, yaw, 0)
        eyeLeft?.eulerAngles = euler
        eyeRight?.eulerAngles = euler
    }

    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(x, lo), hi)
    }
}
