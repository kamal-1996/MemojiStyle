import SceneKit
import simd

/// Central avatar animation brain (Phase 3 + 5).
///
/// Receives device-independent `FaceTrackingData`, applies smoothing, drives the
/// facial rig, gaze and head orientation, and advances hair each frame. It does
/// NOT own the ARSession — tracking is pushed in from `FaceTrackingManager`.
final class AvatarController {

    var params = SmoothingParameters()
    /// Mirror head yaw/roll so it feels like looking in a mirror. Tune on device.
    var mirrored = true

    private let rig: AvatarFaceRig
    private let driver: RigDriver
    private let nodes: AvatarRigNodes

    private let expression = ExpressionController()
    private let eye: EyeController
    let hair: HairMotionController

    private var rotationSmoother = QuaternionSmoother()
    private var currentHeadRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    private var isTracked = false

    init(rig: AvatarFaceRig, driver: RigDriver, nodes: AvatarRigNodes) {
        self.rig = rig
        self.driver = driver
        self.nodes = nodes
        self.eye = EyeController(eyeLeft: nodes.eyeLeft, eyeRight: nodes.eyeRight)
        self.hair = HairMotionController(strands: nodes.hairStrands)
    }

    /// Push a new tracking frame (called from the tracking subscription).
    func apply(_ data: FaceTrackingData) {
        guard data.state == .tracked else {
            isTracked = false
            return
        }
        isTracked = true

        // Facial expressions.
        let channels = rig.resolve(data)
        let processed = expression.process(channels, params: params)
        driver.apply(channels: processed)

        // Gaze (procedural eye nodes). Uses raw channels; EyeController smooths.
        eye.update(channels: channels, smoothing: params.eyeSmoothing)

        // Head orientation.
        var target = data.headRotation
        if mirrored {
            // Flip yaw (Y) and roll (Z) to mirror the user.
            target = simd_quatf(ix: target.imag.x,
                                iy: -target.imag.y,
                                iz: -target.imag.z,
                                r: target.real)
        }
        let smoothed = rotationSmoother.update(target: target, smoothing: params.rotationSmoothing)
        currentHeadRotation = smoothed
        nodes.headPivot.simdOrientation = smoothed
    }

    /// Advance secondary motion. Call once per rendered frame.
    func tick(dt: TimeInterval) {
        hair.update(headRotation: currentHeadRotation, dt: dt)
    }

    func resetToNeutral() {
        rotationSmoother.reset()
        hair.reset()
        currentHeadRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        nodes.headPivot.simdOrientation = currentHeadRotation
    }
}
