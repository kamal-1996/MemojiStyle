import SwiftUI
import ARKit
import SceneKit

/// The heart of the app: an `ARSCNView` that runs face tracking, renders the
/// avatar over the (optional) camera background, advances hair each frame, and
/// serves as the frame source for recording.
struct AvatarSceneView: UIViewRepresentable {
    @ObservedObject var appState: AppState

    func makeCoordinator() -> Coordinator { Coordinator(appState: appState) }

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.automaticallyUpdatesLighting = false
        arView.rendersContinuously = true            // keep the loop alive for hair/idle
        arView.antialiasingMode = .multisampling4X
        arView.delegate = context.coordinator
        arView.scene = SCNScene()

        // Share the tracking session so face anchors flow through the delegate.
        arView.session = appState.faceTracking.session

        // Build the scene: avatar + lights + camera.
        let avatarRoot = appState.avatarManager.rootNode
        arView.scene.rootNode.addChildNode(avatarRoot)
        SceneLighting.configureLights(in: arView.scene)
        let cameraNode = SceneLighting.configureCamera(in: arView.scene, lookingAt: SCNVector3(0, 0.02, 0))
        // Render the avatar from our fixed camera (not the device/AR camera POV),
        // while ARSCNView keeps drawing the live camera feed as the background.
        arView.pointOfView = cameraNode

        BackgroundController.apply(appState.backgroundMode, to: arView, color: .black)

        // Let recording snapshot this exact view.
        appState.recording.attach(view: arView)

        // Start tracking.
        appState.faceTracking.start()

        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        BackgroundController.apply(appState.backgroundMode, to: uiView, color: .black)
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, ARSCNViewDelegate {
        weak var arView: ARSCNView?
        private let appState: AppState
        private var lastTime: TimeInterval = 0

        init(appState: AppState) {
            self.appState = appState
        }

        // Face anchor lifecycle -> feed the tracking manager.
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            ingest(anchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            ingest(anchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            if anchor is ARFaceAnchor { appState.faceTracking.markNoFace() }
        }

        // ARSessionObserver (forwarded by ARSCNView) -> FPS + camera buffer.
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            appState.faceTracking.noteFrame(frame)
        }

        // Render loop: drive the avatar + hair from the latest tracking data.
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt = lastTime == 0 ? 1.0 / 60.0 : time - lastTime
            lastTime = time

            let controller = appState.avatarManager.controller
            syncSettings(into: controller)

            controller.apply(appState.faceTracking.latest)
            controller.tick(dt: dt)
        }

        private func ingest(_ anchor: ARAnchor) {
            guard let face = anchor as? ARFaceAnchor else { return }
            let timestamp = arView?.session.currentFrame?.timestamp ?? CACurrentMediaTime()
            appState.faceTracking.ingest(faceAnchor: face, timestamp: timestamp)
        }

        private func syncSettings(into controller: AvatarController) {
            controller.params.expressionMultiplier = appState.expressionStrength
            controller.mirrored = appState.mirrored
            controller.hair.parameters.enabled = appState.hairEnabled
        }
    }
}
