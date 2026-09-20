import ARKit
import simd

/// The set of ARKit blendshapes this app understands.
///
/// We wrap `ARFaceAnchor.BlendShapeLocation` in our own enum so the rest of the
/// app never imports ARKit just to reference a coefficient name. Not every
/// device/OS reports every location, so callers must treat missing values as 0.
enum Blendshape: String, CaseIterable {
    case eyeBlinkLeft, eyeBlinkRight
    case eyeLookInLeft, eyeLookInRight
    case eyeLookOutLeft, eyeLookOutRight
    case eyeLookUpLeft, eyeLookUpRight
    case eyeLookDownLeft, eyeLookDownRight
    case browDownLeft, browDownRight
    case browInnerUp
    case browOuterUpLeft, browOuterUpRight
    case jawOpen
    case mouthSmileLeft, mouthSmileRight
    case mouthFunnel, mouthPucker
    case mouthLeft, mouthRight
    case mouthClose
    case cheekPuff
    case cheekSquintLeft, cheekSquintRight
    case noseSneerLeft, noseSneerRight

    /// The matching ARKit location key.
    var arkitLocation: ARFaceAnchor.BlendShapeLocation {
        switch self {
        case .eyeBlinkLeft:      return .eyeBlinkLeft
        case .eyeBlinkRight:     return .eyeBlinkRight
        case .eyeLookInLeft:     return .eyeLookInLeft
        case .eyeLookInRight:    return .eyeLookInRight
        case .eyeLookOutLeft:    return .eyeLookOutLeft
        case .eyeLookOutRight:   return .eyeLookOutRight
        case .eyeLookUpLeft:     return .eyeLookUpLeft
        case .eyeLookUpRight:    return .eyeLookUpRight
        case .eyeLookDownLeft:   return .eyeLookDownLeft
        case .eyeLookDownRight:  return .eyeLookDownRight
        case .browDownLeft:      return .browDownLeft
        case .browDownRight:     return .browDownRight
        case .browInnerUp:       return .browInnerUp
        case .browOuterUpLeft:   return .browOuterUpLeft
        case .browOuterUpRight:  return .browOuterUpRight
        case .jawOpen:           return .jawOpen
        case .mouthSmileLeft:    return .mouthSmileLeft
        case .mouthSmileRight:   return .mouthSmileRight
        case .mouthFunnel:       return .mouthFunnel
        case .mouthPucker:       return .mouthPucker
        case .mouthLeft:         return .mouthLeft
        case .mouthRight:        return .mouthRight
        case .mouthClose:        return .mouthClose
        case .cheekPuff:         return .cheekPuff
        case .cheekSquintLeft:   return .cheekSquintLeft
        case .cheekSquintRight:  return .cheekSquintRight
        case .noseSneerLeft:     return .noseSneerLeft
        case .noseSneerRight:    return .noseSneerRight
        }
    }
}

/// A device-independent snapshot of one face-tracking frame.
///
/// This is the ONLY type the avatar/animation layers consume. It contains no
/// ARKit objects, so nothing downstream needs to know how tracking is produced.
struct FaceTrackingData {
    enum State: Equatable {
        case notTracked
        case tracked
    }

    var state: State
    /// Full head pose (rotation + translation) in the AR session's world space.
    var headTransform: simd_float4x4
    /// Convenience: translation component of `headTransform`.
    var headPosition: SIMD3<Float>
    /// Convenience: rotation component of `headTransform`.
    var headRotation: simd_quatf
    /// Clamped [0...1] blendshape coefficients. Missing keys are simply absent.
    var blendshapes: [Blendshape: Float]
    /// AR frame timestamp (seconds). Useful for smoothing / velocity.
    var timestamp: TimeInterval

    /// Safe accessor — returns 0 for any coefficient the device didn't report.
    func value(_ shape: Blendshape) -> Float {
        blendshapes[shape] ?? 0
    }

    static var idle: FaceTrackingData {
        FaceTrackingData(
            state: .notTracked,
            headTransform: matrix_identity_float4x4,
            headPosition: .zero,
            headRotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            blendshapes: [:],
            timestamp: 0
        )
    }
}

extension FaceTrackingData {
    /// Builds our model from an ARKit face anchor.
    init(anchor: ARFaceAnchor, timestamp: TimeInterval) {
        let transform = anchor.transform
        var shapes: [Blendshape: Float] = [:]
        shapes.reserveCapacity(Blendshape.allCases.count)
        for shape in Blendshape.allCases {
            if let number = anchor.blendShapes[shape.arkitLocation] {
                // Clamp defensively; ARKit is usually in [0,1] but be safe.
                shapes[shape] = min(max(number.floatValue, 0), 1)
            }
        }

        self.state = anchor.isTracked ? .tracked : .notTracked
        self.headTransform = transform
        self.headPosition = SIMD3<Float>(transform.columns.3.x,
                                         transform.columns.3.y,
                                         transform.columns.3.z)
        self.headRotation = simd_quatf(transform)
        self.blendshapes = shapes
        self.timestamp = timestamp
    }
}
