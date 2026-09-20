import ARKit
import AVFoundation
import SceneKit
import UIKit

/// Records the fully-composited `ARSCNView` (camera background + avatar) plus
/// microphone audio to a local file (Phase 10).
///
/// Approach: a `CADisplayLink` grabs `view.snapshot()` at the target FPS,
/// scales it into a `CVPixelBuffer`, and appends to an `AVAssetWriter`. Video
/// frames and audio samples are timestamped on the shared host-time clock so
/// they stay in sync. Snapshotting is simple and correct; on older devices at
/// 4K it can be heavy — the config auto-falls back (see `CaptureConfiguration`).
final class SceneRecorder {

    private weak var view: ARSCNView?
    private let queue = DispatchQueue(label: "scene.recorder.write")

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var displayLink: CADisplayLink?
    private var renderSize: CGSize = .zero

    private var sessionStarted = false
    private var startTime = CMTime.zero
    private(set) var isRecording = false

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Starts recording. Returns false if the writer couldn't be created.
    @discardableResult
    func start(view: ARSCNView, config: CaptureConfiguration, url: URL) -> Bool {
        guard !isRecording else { return false }
        self.view = view
        self.renderSize = config.renderSize

        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            return false
        }

        // Video input.
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: config.codec,
            AVVideoWidthKey: Int(config.renderSize.width),
            AVVideoHeightKey: Int(config.renderSize.height)
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(config.renderSize.width),
            kCVPixelBufferHeightKey as String: Int(config.renderSize.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput,
                                                           sourcePixelBufferAttributes: attrs)
        if writer.canAdd(vInput) { writer.add(vInput) }

        // Audio input.
        if config.hasAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 96000
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            if writer.canAdd(aInput) { writer.add(aInput) }
            self.audioInput = aInput
        }

        writer.startWriting()

        self.writer = writer
        self.videoInput = vInput
        self.adaptor = adaptor
        self.sessionStarted = false
        self.isRecording = true

        // Drive frame capture on the main run loop at the target FPS.
        let link = CADisplayLink(target: self, selector: #selector(captureFrame))
        link.preferredFramesPerSecond = config.fps
        link.add(to: .main, forMode: .common)
        self.displayLink = link
        return true
    }

    func stop(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer = writer else {
            completion(nil); return
        }
        isRecording = false
        displayLink?.invalidate()
        displayLink = nil

        queue.async { [weak self] in
            self?.videoInput?.markAsFinished()
            self?.audioInput?.markAsFinished()
            writer.finishWriting {
                let url = writer.status == .completed ? writer.outputURL : nil
                DispatchQueue.main.async { completion(url) }
            }
        }
    }

    /// Feed a microphone sample buffer (from `AudioManager`).
    func append(audio sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self,
                  self.isRecording,
                  self.sessionStarted,
                  let input = self.audioInput,
                  input.isReadyForMoreMediaData else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if pts >= self.startTime {
                input.append(sampleBuffer)
            }
        }
    }

    // MARK: - Frame capture

    @objc private func captureFrame() {
        guard isRecording, let view = view else { return }
        // snapshot() must run on the main thread (we're on the display link).
        let image = view.snapshot()
        let hostTime = CMClockGetTime(CMClockGetHostTimeClock())

        queue.async { [weak self] in
            self?.encode(image: image, at: hostTime)
        }
    }

    private func encode(image: UIImage, at time: CMTime) {
        guard let writer = writer,
              let adaptor = adaptor,
              let input = videoInput,
              writer.status == .writing else { return }

        if !sessionStarted {
            startTime = time
            writer.startSession(atSourceTime: time)
            sessionStarted = true
        }

        guard input.isReadyForMoreMediaData,
              let pool = adaptor.pixelBufferPool,
              let buffer = makePixelBuffer(from: image, pool: pool) else { return }

        adaptor.append(buffer, withPresentationTime: time)
    }

    private func makePixelBuffer(from image: UIImage, pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer,
              let ciImage = CIImage(image: image) else { return nil }

        // Aspect-fill scale the snapshot into the target render size.
        let scaleX = renderSize.width / ciImage.extent.width
        let scaleY = renderSize.height / ciImage.extent.height
        let scale = max(scaleX, scaleY)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        ciContext.render(scaled, to: buffer)
        return buffer
    }
}
