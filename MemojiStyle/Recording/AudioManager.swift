import AVFoundation

/// Captures microphone audio as `CMSampleBuffer`s and forwards them to a sink
/// (the recorder). Uses a dedicated audio-only `AVCaptureSession`, which runs
/// happily alongside ARKit's camera session.
///
/// Buffers are timestamped on the shared host-time clock so they line up with
/// the video frames (which we timestamp from the same clock).
final class AudioManager: NSObject {

    /// Called on the audio capture queue with each mic sample buffer.
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "audio.capture.queue")
    private(set) var isConfigured = false

    func configure() {
        guard !isConfigured else { return }
        session.beginConfiguration()

        if let device = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            output.setSampleBufferDelegate(self, queue: queue)
            session.addOutput(output)
        }
        session.commitConfiguration()
        isConfigured = true
    }

    func start() {
        guard isConfigured else { return }
        if !session.isRunning {
            queue.async { [weak self] in self?.session.startRunning() }
        }
    }

    func stop() {
        if session.isRunning {
            queue.async { [weak self] in self?.session.stopRunning() }
        }
    }
}

extension AudioManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)
    }
}
