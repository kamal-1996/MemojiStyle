import Foundation
import simd

/// Tunable smoothing parameters (Phase 5). Exposed to the UI as
/// "Expression strength" and internal smoothing sliders.
struct SmoothingParameters {
    /// 0 = no smoothing (raw/jittery), 1 = very heavy smoothing (laggy).
    /// A good responsive-but-stable default is ~0.35.
    var positionSmoothing: Float = 0.35
    var rotationSmoothing: Float = 0.35
    var eyeSmoothing: Float = 0.4
    var mouthSmoothing: Float = 0.25
    var expressionSmoothing: Float = 0.3

    /// Below this magnitude, input is treated as 0 to kill micro-jitter.
    var deadZone: Float = 0.02
    /// Expression coefficients are multiplied by this (UI "expression strength").
    var expressionMultiplier: Float = 1.0
    /// Hard ceiling so we never over-amplify a coefficient.
    var maxExpression: Float = 1.0
}

/// Exponential smoothing filter for a scalar value.
///
/// `smoothing` is a 0...1 weight: output = lerp(current, target, 1 - smoothing).
/// Higher smoothing = slower response. Frame-rate independent enough for our
/// 60 fps target; for large frame-time swings this is intentionally simple.
struct ScalarSmoother {
    private var value: Float = 0
    private var initialized = false

    mutating func update(target: Float, smoothing: Float) -> Float {
        let clampedSmoothing = min(max(smoothing, 0), 0.99)
        if !initialized {
            value = target
            initialized = true
            return value
        }
        value += (target - value) * (1 - clampedSmoothing)
        return value
    }

    mutating func reset() { initialized = false; value = 0 }
}

/// Spherical-linear smoothing for rotations.
struct QuaternionSmoother {
    private var value = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    private var initialized = false

    mutating func update(target: simd_quatf, smoothing: Float) -> simd_quatf {
        let t = 1 - min(max(smoothing, 0), 0.99)
        if !initialized {
            value = target
            initialized = true
            return value
        }
        value = simd_slerp(value, target, t)
        return value
    }

    mutating func reset() { initialized = false }
}

/// Vector smoothing for positions.
struct VectorSmoother {
    private var value = SIMD3<Float>.zero
    private var initialized = false

    mutating func update(target: SIMD3<Float>, smoothing: Float) -> SIMD3<Float> {
        let t = 1 - min(max(smoothing, 0), 0.99)
        if !initialized {
            value = target
            initialized = true
            return value
        }
        value += (target - value) * t
        return value
    }

    mutating func reset() { initialized = false }
}

enum SmoothingMath {
    /// Applies dead-zone + multiplier + clamp to a raw expression coefficient.
    static func conditionExpression(_ raw: Float, params: SmoothingParameters) -> Float {
        let dz = abs(raw) < params.deadZone ? 0 : raw
        return min(dz * params.expressionMultiplier, params.maxExpression)
    }
}
