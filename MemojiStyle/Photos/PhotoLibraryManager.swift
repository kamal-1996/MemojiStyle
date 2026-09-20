import Photos
import Foundation

/// Saves finished recordings to the user's Photos library (Phase 12).
///
/// Requests add-only permission, saves locally, and reports success/failure.
/// No cloud upload — this is purely the on-device Photos library.
enum PhotoLibraryManager {

    enum SaveResult {
        case saved
        case denied
        case failed(String)
    }

    static func save(_ url: URL, completion: @escaping (SaveResult) -> Void) {
        requestAddAccess { granted in
            guard granted else {
                DispatchQueue.main.async { completion(.denied) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.saved)
                    } else {
                        completion(.failed(error?.localizedDescription ?? "Unknown error"))
                    }
                }
            }
        }
    }

    private static func requestAddAccess(_ completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                completion(newStatus == .authorized || newStatus == .limited)
            }
        default:
            completion(false)
        }
    }
}
