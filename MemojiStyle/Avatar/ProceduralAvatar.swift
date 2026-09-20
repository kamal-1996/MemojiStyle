import SceneKit
import UIKit

/// Builds an ORIGINAL, stylized 3D cartoon head entirely in code.
///
/// This is a placeholder so the full pipeline (tracking → rig → hair →
/// recording) works without shipping a binary asset. It is NOT derived from
/// Apple's Memoji in any way — it is simple original geometry.
///
/// Phase 4 / 13: replace this with `AvatarManager.loadUSDZ(...)` pointing at your
/// own rigged `CustomAvatar.usdz` (head, eyes, brows, jaw, teeth, hair bones,
/// ARKit-style blendshapes). The rest of the app does not change.
enum ProceduralAvatar {

    static func build() -> AvatarRigNodes {
        let root = SCNNode()
        root.name = "AvatarRoot"

        let headPivot = SCNNode()
        headPivot.name = "HeadPivot"
        root.addChildNode(headPivot)

        // Head
        let head = SCNNode(geometry: sphere(radius: 0.09,
                                            color: UIColor(red: 1.0, green: 0.86, blue: 0.75, alpha: 1)))
        head.name = "Head"
        headPivot.addChildNode(head)

        // Eyes (white sphere + dark pupil), placed on the face front (+Z).
        let (eyeL, lidL) = makeEye()
        eyeL.position = SCNVector3(-0.032, 0.015, 0.078)
        let (eyeR, lidR) = makeEye()
        eyeR.position = SCNVector3(0.032, 0.015, 0.078)
        headPivot.addChildNode(eyeL)
        headPivot.addChildNode(eyeR)

        // Eyebrows
        let browL = brow()
        browL.position = SCNVector3(-0.032, 0.045, 0.086)
        let browR = brow()
        browR.position = SCNVector3(0.032, 0.045, 0.086)
        headPivot.addChildNode(browL)
        headPivot.addChildNode(browR)

        // Jaw + mouth
        let jaw = SCNNode()
        jaw.name = "Jaw"
        jaw.position = SCNVector3(0, -0.02, 0)     // pivot near jaw hinge
        headPivot.addChildNode(jaw)

        let mouth = SCNNode(geometry: capsuleMouth())
        mouth.name = "Mouth"
        mouth.position = SCNVector3(0, -0.028, 0.083)
        jaw.addChildNode(mouth)

        // Hair — several strands of chained bones on top/back of the head.
        let (hairContainer, strands) = makeHair()
        hairContainer.position = SCNVector3(0, 0.06, -0.01)
        headPivot.addChildNode(hairContainer)

        return AvatarRigNodes(
            root: root,
            headPivot: headPivot,
            jaw: jaw,
            eyeLeft: eyeL,
            eyeRight: eyeR,
            eyelidLeft: lidL,
            eyelidRight: lidR,
            browLeft: browL,
            browRight: browR,
            mouth: mouth,
            hairStrands: strands,
            morpherOwners: []
        )
    }

    // MARK: - Pieces

    private static func makeEye() -> (eye: SCNNode, lid: SCNNode) {
        let eye = SCNNode()
        eye.name = "Eye"

        let white = SCNNode(geometry: sphere(radius: 0.016, color: .white))
        eye.addChildNode(white)

        let pupil = SCNNode(geometry: sphere(radius: 0.007, color: UIColor(white: 0.05, alpha: 1)))
        pupil.name = "Pupil"
        pupil.position = SCNVector3(0, 0, 0.012)
        eye.addChildNode(pupil)

        // Eyelid: a thin cap we scale on Y to blink.
        let lidGeo = SCNSphere(radius: 0.0175)
        lidGeo.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.86, blue: 0.75, alpha: 1)
        let lid = SCNNode(geometry: lidGeo)
        lid.name = "Eyelid"
        lid.scale = SCNVector3(1, 1, 0.4)  // start open
        eye.addChildNode(lid)

        return (eye, lid)
    }

    private static func brow() -> SCNNode {
        let geo = SCNBox(width: 0.03, height: 0.006, length: 0.006, chamferRadius: 0.002)
        geo.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1)
        let node = SCNNode(geometry: geo)
        node.name = "Brow"
        return node
    }

    private static func capsuleMouth() -> SCNGeometry {
        let geo = SCNCapsule(capRadius: 0.006, height: 0.03)
        geo.firstMaterial?.diffuse.contents = UIColor(red: 0.6, green: 0.2, blue: 0.25, alpha: 1)
        return geo
    }

    /// Builds hair as several chains of 3 bones each. Returns the container and
    /// the ordered bone chains for `HairMotionController`.
    private static func makeHair() -> (container: SCNNode, strands: [[SCNNode]]) {
        let container = SCNNode()
        container.name = "HairRoot"

        var strands: [[SCNNode]] = []
        let strandColor = UIColor(red: 0.35, green: 0.2, blue: 0.12, alpha: 1)

        // Distribute strand roots across the top of the head.
        let roots: [SCNVector3] = [
            SCNVector3(-0.05, 0.02, 0.0), SCNVector3(-0.025, 0.03, 0.02),
            SCNVector3(0.0, 0.035, 0.02), SCNVector3(0.025, 0.03, 0.02),
            SCNVector3(0.05, 0.02, 0.0), SCNVector3(-0.04, 0.02, -0.03),
            SCNVector3(0.0, 0.03, -0.04), SCNVector3(0.04, 0.02, -0.03)
        ]

        for rootPos in roots {
            var chain: [SCNNode] = []
            var parent = container
            let segments = 3
            for i in 0..<segments {
                let bone = SCNNode()
                bone.name = "HairBone_\(strands.count)_\(i)"
                if i == 0 {
                    bone.position = rootPos
                } else {
                    bone.position = SCNVector3(0, -0.025, 0) // hang downward from parent
                }
                // Visible strand segment (tips thinner).
                let radius = 0.006 - Float(i) * 0.0012
                let seg = SCNCapsule(capRadius: CGFloat(max(0.002, radius)), height: 0.026)
                seg.firstMaterial?.diffuse.contents = strandColor
                let mesh = SCNNode(geometry: seg)
                mesh.position = SCNVector3(0, -0.013, 0)
                bone.addChildNode(mesh)

                parent.addChildNode(bone)
                chain.append(bone)
                parent = bone
            }
            strands.append(chain)
        }
        return (container, strands)
    }

    // MARK: - Helpers

    private static func sphere(radius: CGFloat, color: UIColor) -> SCNSphere {
        let geo = SCNSphere(radius: radius)
        geo.segmentCount = 48
        let mat = geo.firstMaterial
        mat?.diffuse.contents = color
        mat?.lightingModel = .physicallyBased
        mat?.roughness.contents = 0.6
        return geo
    }
}
