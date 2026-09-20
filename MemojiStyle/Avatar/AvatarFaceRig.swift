import Foundation

/// Semantic controls the avatar exposes, independent of ARKit naming.
///
/// A real rigged model may name its morph targets differently (e.g. "eyeBlink_L"
/// or "JawOpen"). `AvatarFaceRig` maps each ARKit `Blendshape` to one of these
/// semantic channels, and the active `RigDriver` knows how to realize the
/// channel on the concrete model (morph target weight, bone rotation, etc.).
enum AvatarChannel: String, CaseIterable {
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
}

/// Configurable mapping ARKit → avatar.
///
/// Default is a 1:1 mapping (identity) but every entry can be re-pointed, given
/// a custom weight, or disabled. For a real USDZ, also set
/// `morphTargetName(for:)` so the morpher driver can find each channel.
struct AvatarFaceRig {

    struct Mapping {
        var channel: AvatarChannel
        /// Scales this specific channel (independent of the global multiplier).
        var weight: Float = 1.0
        var enabled: Bool = true
    }

    /// ARKit blendshape → avatar channel mapping.
    private(set) var mappings: [Blendshape: Mapping]

    /// Avatar channel → morph-target node name in the loaded USDZ (optional).
    /// Only used by `MorpherRigDriver`. The procedural driver ignores this.
    var morphTargetNames: [AvatarChannel: String]

    init(mappings: [Blendshape: Mapping]? = nil,
         morphTargetNames: [AvatarChannel: String] = [:]) {
        if let mappings {
            self.mappings = mappings
        } else {
            // Identity: eyeBlinkLeft → .eyeBlinkLeft, etc.
            var identity: [Blendshape: Mapping] = [:]
            for shape in Blendshape.allCases {
                if let channel = AvatarChannel(rawValue: shape.rawValue) {
                    identity[shape] = Mapping(channel: channel)
                }
            }
            self.mappings = identity
        }
        self.morphTargetNames = morphTargetNames
    }

    /// Resolves raw ARKit coefficients into per-channel avatar values.
    func resolve(_ data: FaceTrackingData) -> [AvatarChannel: Float] {
        var result: [AvatarChannel: Float] = [:]
        for (shape, mapping) in mappings where mapping.enabled {
            let raw = data.value(shape) * mapping.weight
            // If two ARKit shapes map to the same channel, keep the stronger.
            result[mapping.channel] = max(result[mapping.channel] ?? 0, raw)
        }
        return result
    }

    func morphTargetName(for channel: AvatarChannel) -> String? {
        morphTargetNames[channel]
    }

    /// Preset for avatars exported with **standard ARKit blendshape names**
    /// (Ready Player Me, Reallusion Character Creator, most ARKit-ready USDZs).
    ///
    /// Those tools name each morph target exactly like ARKit's location keys
    /// (e.g. "jawOpen", "eyeBlinkLeft"), which are identical to our
    /// `AvatarChannel` raw values — so the mapping is 1:1.
    static var standardARKit: AvatarFaceRig {
        var names: [AvatarChannel: String] = [:]
        for channel in AvatarChannel.allCases {
            names[channel] = channel.rawValue
        }
        return AvatarFaceRig(morphTargetNames: names)
    }
}
