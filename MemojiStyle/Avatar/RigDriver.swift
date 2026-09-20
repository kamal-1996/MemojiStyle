import SceneKit
import simd

/// Weak references to the animatable nodes of the loaded avatar.
///
/// Populated either by `ProceduralAvatar` (placeholder) or by parsing a real
/// USDZ. Drivers and controllers manipulate these nodes each frame.
final class AvatarRigNodes {
    let root: SCNNode
    /// Rotated to reproduce head orientation.
    let headPivot: SCNNode
    /// Optional bone/nodes for procedural facial articulation.
    let jaw: SCNNode?
    let eyeLeft: SCNNode?
    let eyeRight: SCNNode?
    let eyelidLeft: SCNNode?
    let eyelidRight: SCNNode?
    let browLeft: SCNNode?
    let browRight: SCNNode?
    let mouth: SCNNode?
    /// Each strand is an ordered chain of bones (root → tip) for hair physics.
    let hairStrands: [[SCNNode]]
    /// Nodes that may carry an `SCNMorpher` (real rigged models).
    let morpherOwners: [SCNNode]

    init(root: SCNNode,
         headPivot: SCNNode,
         jaw: SCNNode? = nil,
         eyeLeft: SCNNode? = nil,
         eyeRight: SCNNode? = nil,
         eyelidLeft: SCNNode? = nil,
         eyelidRight: SCNNode? = nil,
         browLeft: SCNNode? = nil,
         browRight: SCNNode? = nil,
         mouth: SCNNode? = nil,
         hairStrands: [[SCNNode]] = [],
         morpherOwners: [SCNNode] = []) {
        self.root = root
        self.headPivot = headPivot
        self.jaw = jaw
        self.eyeLeft = eyeLeft
        self.eyeRight = eyeRight
        self.eyelidLeft = eyelidLeft
        self.eyelidRight = eyelidRight
        self.browLeft = browLeft
        self.browRight = browRight
        self.mouth = mouth
        self.hairStrands = hairStrands
        self.morpherOwners = morpherOwners
    }
}

/// Something that can realize per-channel avatar values on a concrete model.
protocol RigDriver: AnyObject {
    /// `channels` values are already smoothed + conditioned (0...1).
    func apply(channels: [AvatarChannel: Float])
}

/// Drives a real rigged USDZ by setting `SCNMorpher` weights by target name.
///
/// Use this when your avatar was authored with ARKit-compatible blendshapes.
/// The rig's `morphTargetNames` supplies the target name for each channel.
final class MorpherRigDriver: RigDriver {
    private let rig: AvatarFaceRig
    private let morpherOwners: [SCNNode]

    init(rig: AvatarFaceRig, morpherOwners: [SCNNode]) {
        self.rig = rig
        self.morpherOwners = morpherOwners
    }

    func apply(channels: [AvatarChannel: Float]) {
        for (channel, value) in channels {
            guard let name = rig.morphTargetName(for: channel) else { continue }
            for owner in morpherOwners {
                guard let morpher = owner.morpher else { continue }
                // Only touch a target the morpher actually has.
                if morpher.targets.contains(where: { $0.name == name }) {
                    morpher.setWeight(CGFloat(value), forTargetNamed: name)
                }
            }
        }
    }
}

/// Drives the procedural placeholder avatar by transforming its nodes.
///
/// This lets the whole pipeline run and be validated *without* a real rigged
/// asset. Eye-look channels are intentionally ignored here — `EyeController`
/// owns eye rotation so smoothing/limits live in one place.
final class ProceduralRigDriver: RigDriver {
    private let nodes: AvatarRigNodes

    // Neutral transforms captured at init so we can offset from rest pose.
    private let jawRest: Float
    private let browLeftRest: Float
    private let browRightRest: Float

    init(nodes: AvatarRigNodes) {
        self.nodes = nodes
        self.jawRest = nodes.jaw?.eulerAngles.x ?? 0
        self.browLeftRest = nodes.browLeft?.position.y ?? 0
        self.browRightRest = nodes.browRight?.position.y ?? 0
    }

    func apply(channels: [AvatarChannel: Float]) {
        func v(_ c: AvatarChannel) -> Float { channels[c] ?? 0 }

        // Jaw: rotate open around X. ~0.45 rad at full open.
        if let jaw = nodes.jaw {
            jaw.eulerAngles.x = jawRest + v(.jawOpen) * 0.45
        }

        // Eyelids: squash Y toward 0 to close. blink 1 => nearly closed.
        if let lid = nodes.eyelidLeft {
            lid.scale.y = max(0.05, 1 - v(.eyeBlinkLeft))
        }
        if let lid = nodes.eyelidRight {
            lid.scale.y = max(0.05, 1 - v(.eyeBlinkRight))
        }

        // Brows: raise/lower on Y. innerUp/outerUp raise; browDown lowers.
        if let brow = nodes.browLeft {
            let up = max(v(.browOuterUpLeft), v(.browInnerUp))
            let down = v(.browDownLeft)
            brow.position.y = browLeftRest + (up - down) * 0.012
        }
        if let brow = nodes.browRight {
            let up = max(v(.browOuterUpRight), v(.browInnerUp))
            let down = v(.browDownRight)
            brow.position.y = browRightRest + (up - down) * 0.012
        }

        // Mouth: blend a couple of shape cues into scale for a readable result.
        if let mouth = nodes.mouth {
            let smile = max(v(.mouthSmileLeft), v(.mouthSmileRight))
            let pucker = max(v(.mouthPucker), v(.mouthFunnel))
            let open = v(.jawOpen)
            mouth.scale.x = 1 + smile * 0.5 - pucker * 0.4
            mouth.scale.y = 1 + open * 0.6 + pucker * 0.2
        }
    }
}
