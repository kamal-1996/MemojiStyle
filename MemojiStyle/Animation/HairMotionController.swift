import SceneKit
import simd

/// Tunable hair dynamics (Phase 7). Lightweight spring-damper, not full physics.
struct HairParameters {
    /// Pull back toward rest pose. Higher = snappier/stiffer.
    var stiffness: Float = 90
    /// Energy loss. Higher = settles faster, less swing.
    var damping: Float = 12
    /// How strongly head motion drives the hair (the "lag/swing" feel).
    var movementMultiplier: Float = 1.4
    /// Max angular offset per bone (radians) to avoid unnatural stretching.
    var maxRotation: Float = 0.5
    /// Constant downward bias so hair hangs naturally.
    var gravityInfluence: Float = 0.6
    /// Global on/off (UI "Hair movement").
    var enabled: Bool = true
}

/// Adds natural secondary motion to the avatar's hair.
///
/// Deliberately ARKit-agnostic: it only receives the head's orientation and a
/// time step. It derives angular velocity itself and applies a per-bone
/// spring-damper so tips lag, swing, and settle after the head moves/stops.
final class HairMotionController {

    var parameters = HairParameters()

    private let strands: [[SCNNode]]

    // Per-bone dynamic state (offset + velocity) for two axes (pitch=X, yaw=Y).
    private struct BoneState {
        var restEuler: SCNVector3
        var offset = SIMD2<Float>(0, 0)   // (x, y)
        var velocity = SIMD2<Float>(0, 0)
    }
    private var states: [[BoneState]] = []

    private var previousRotation: simd_quatf?

    init(strands: [[SCNNode]]) {
        self.strands = strands
        self.states = strands.map { chain in
            chain.map { BoneState(restEuler: $0.eulerAngles) }
        }
    }

    /// Call once per rendered frame.
    /// - Parameters:
    ///   - headRotation: current head orientation (world space).
    ///   - dt: seconds since last update. Clamped internally for stability.
    func update(headRotation: simd_quatf, dt: TimeInterval) {
        guard parameters.enabled else { return }
        let step = Float(min(max(dt, 1.0 / 120.0), 1.0 / 20.0))

        // Head angular velocity (rad/s) from the delta rotation.
        var angularVelocity = SIMD3<Float>(0, 0, 0)
        if let prev = previousRotation {
            let delta = headRotation * prev.inverse
            let angle = delta.angle
            if angle > 1e-5 {
                angularVelocity = simd_normalize(delta.axis) * (angle / step)
            }
        }
        previousRotation = headRotation

        // Drive term: head yaw (Y) pushes hair sideways, head pitch (X) fore/aft.
        let drive = SIMD2<Float>(-angularVelocity.x, -angularVelocity.y) * parameters.movementMultiplier

        for (s, chain) in strands.enumerated() {
            let boneCount = chain.count
            for (i, bone) in chain.enumerated() {
                // Tips move more than roots.
                let boneFactor = Float(i + 1) / Float(boneCount)
                var state = states[s][i]

                let gravity = SIMD2<Float>(parameters.gravityInfluence * boneFactor * 0.15, 0)
                let external = drive * boneFactor + gravity

                // Spring-damper: a = -k*x - c*v + drive
                let accel = -parameters.stiffness * state.offset
                          - parameters.damping * state.velocity
                          + external * parameters.stiffness

                state.velocity += accel * step
                state.offset += state.velocity * step

                // Clamp to keep motion believable.
                state.offset.x = clamp(state.offset.x, -parameters.maxRotation, parameters.maxRotation)
                state.offset.y = clamp(state.offset.y, -parameters.maxRotation, parameters.maxRotation)

                bone.eulerAngles = SCNVector3(
                    state.restEuler.x + state.offset.x,
                    state.restEuler.y + state.offset.y,
                    state.restEuler.z
                )
                states[s][i] = state
            }
        }
    }

    func reset() {
        previousRotation = nil
        for s in states.indices {
            for i in states[s].indices {
                states[s][i].offset = .zero
                states[s][i].velocity = .zero
            }
        }
    }

    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float { min(max(x, lo), hi) }
}
