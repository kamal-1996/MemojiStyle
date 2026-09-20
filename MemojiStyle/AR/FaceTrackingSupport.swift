import ARKit

/// Central place to answer "can this device do ARKit face tracking?"
///
/// ARFaceTrackingConfiguration requires a TrueDepth front camera (Face ID
/// devices). We NEVER assume this is available — always ask ARKit at runtime.
enum FaceTrackingSupport {

    /// True on iPhones/iPads with a TrueDepth camera (iPhone X and later, etc.).
    static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// Maximum number of faces ARKit can track on this device (we only need 1).
    static var maximumNumberOfTrackedFaces: Int {
        ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
    }
}
