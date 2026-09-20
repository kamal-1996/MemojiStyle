import SceneKit

/// Loads exactly ONE avatar and wires up the driver + controller.
///
/// Default builds the procedural placeholder. To use your own rigged model,
/// call `init(usdzURL:)` — the manager will detect `SCNMorpher`s and switch to
/// the `MorpherRigDriver` automatically. Everything downstream is identical.
final class AvatarManager {

    let rootNode: SCNNode
    let nodes: AvatarRigNodes
    let controller: AvatarController

    private(set) var rig: AvatarFaceRig

    /// Loads `CustomAvatar.usdz` from the app bundle if you added one (using the
    /// standard ARKit blendshape rig); otherwise falls back to the procedural
    /// placeholder. This is what the app uses at launch — drop in your rigged
    /// USDZ and it "just works".
    static func bundledOrProcedural() -> AvatarManager {
        if let url = Bundle.main.url(forResource: "CustomAvatar", withExtension: "usdz"),
           let loaded = AvatarManager(usdzURL: url, rig: .standardARKit) {
            return loaded
        }
        return AvatarManager()
    }

    /// Placeholder avatar (works with no external asset).
    init(rig: AvatarFaceRig = AvatarFaceRig()) {
        self.rig = rig
        let nodes = ProceduralAvatar.build()
        self.nodes = nodes
        self.rootNode = nodes.root
        let driver = ProceduralRigDriver(nodes: nodes)
        self.controller = AvatarController(rig: rig, driver: driver, nodes: nodes)
    }

    /// Loads a real rigged avatar. `rig.morphTargetNames` must map channels to
    /// the model's blendshape target names for facial animation to appear.
    init?(usdzURL: URL, rig: AvatarFaceRig) {
        guard let scene = try? SCNScene(url: usdzURL, options: [.checkConsistency: true]) else {
            return nil
        }
        self.rig = rig

        let container = SCNNode()
        container.name = "AvatarRoot"
        for child in scene.rootNode.childNodes {
            container.addChildNode(child)
        }

        // Collect nodes that carry morphers (facial blendshapes).
        var morpherOwners: [SCNNode] = []
        container.enumerateHierarchy { node, _ in
            if node.morpher != nil { morpherOwners.append(node) }
        }

        // Best-effort named lookups (author your model with these names, or
        // adjust here to match your rig's node names).
        let headPivot = container.childNode(withName: "HeadPivot", recursively: true) ?? container

        let nodes = AvatarRigNodes(
            root: container,
            headPivot: headPivot,
            jaw: container.childNode(withName: "Jaw", recursively: true),
            eyeLeft: container.childNode(withName: "EyeLeft", recursively: true),
            eyeRight: container.childNode(withName: "EyeRight", recursively: true),
            morpherOwners: morpherOwners
        )

        self.nodes = nodes
        self.rootNode = container

        let driver: RigDriver = morpherOwners.isEmpty
            ? ProceduralRigDriver(nodes: nodes)
            : MorpherRigDriver(rig: rig, morpherOwners: morpherOwners)

        self.controller = AvatarController(rig: rig, driver: driver, nodes: nodes)
    }
}
