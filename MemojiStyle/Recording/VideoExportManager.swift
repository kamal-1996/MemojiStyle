import Foundation

/// Provides output URLs and (optionally) finalizes recordings for saving.
///
/// The `SceneRecorder` already writes a finished MP4, so this manager focuses on
/// giving a unique temp URL and could host future re-encode/trim steps.
enum VideoExportManager {

    /// A unique temporary URL for a new recording.
    static func makeOutputURL() -> URL {
        let name = "MemojiStyle_\(Int(Date().timeIntervalSince1970)).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    /// Removes a temp file after it has been copied to Photos.
    static func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
