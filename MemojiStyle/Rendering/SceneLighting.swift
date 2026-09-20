import SceneKit
import UIKit

/// Sets up a polished, stylized lighting rig and a framing camera (Phase 8).
///
/// Three-point-ish lighting (key/fill/rim) + soft ambient + image-based env for
/// gentle highlights on skin/eyes/hair. Tuned for performance on iPhone.
enum SceneLighting {

    /// Adds a camera framed on the avatar head and returns the camera node.
    @discardableResult
    static func configureCamera(in scene: SCNScene, lookingAt target: SCNVector3) -> SCNNode {
        let cameraNode = SCNNode()
        cameraNode.name = "AvatarCamera"
        let camera = SCNCamera()
        camera.fieldOfView = 30
        camera.zNear = 0.01
        camera.zFar = 10
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(target.x, target.y, target.z + 0.5)
        cameraNode.look(at: target)
        scene.rootNode.addChildNode(cameraNode)
        return cameraNode
    }

    static func configureLights(in scene: SCNScene) {
        // Key light — main soft directional from upper front-left.
        let key = SCNNode()
        key.light = directional(intensity: 900, temp: 6200, shadows: true)
        key.eulerAngles = SCNVector3(-0.6, 0.6, 0)
        scene.rootNode.addChildNode(key)

        // Fill — softer, opposite side, no shadows.
        let fill = SCNNode()
        fill.light = directional(intensity: 350, temp: 7000, shadows: false)
        fill.eulerAngles = SCNVector3(-0.3, -0.8, 0)
        scene.rootNode.addChildNode(fill)

        // Rim/back — separates hair/silhouette from background.
        let rim = SCNNode()
        rim.light = directional(intensity: 500, temp: 8000, shadows: false)
        rim.eulerAngles = SCNVector3(0.5, 3.0, 0)
        scene.rootNode.addChildNode(rim)

        // Ambient — lifts shadows so nothing goes fully black.
        let ambient = SCNNode()
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 250
        ambient.light = amb
        scene.rootNode.addChildNode(ambient)

        // Subtle environment for PBR highlights (procedural gradient).
        scene.lightingEnvironment.contents = UIColor(white: 0.6, alpha: 1)
        scene.lightingEnvironment.intensity = 1.0
    }

    private static func directional(intensity: CGFloat, temp: CGFloat, shadows: Bool) -> SCNLight {
        let light = SCNLight()
        light.type = .directional
        light.intensity = intensity
        light.temperature = temp
        light.castsShadow = shadows
        if shadows {
            light.shadowMode = .deferred
            light.shadowSampleCount = 8
            light.shadowRadius = 4
            light.shadowColor = UIColor(white: 0, alpha: 0.35)
        }
        return light
    }
}
