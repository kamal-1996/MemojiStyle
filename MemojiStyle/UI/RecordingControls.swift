import SwiftUI

/// Record button + duration + save status (Phase 10 / 15).
struct RecordingControls: View {
    @ObservedObject var recording: RecordingManager
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let message = recording.statusMessage {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
            }

            Text(timeString(recording.duration))
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundColor(.white)
                .opacity(recording.isRecording ? 1 : 0.6)

            Button(action: onTap) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 74, height: 74)
                    RoundedRectangle(cornerRadius: recording.isRecording ? 6 : 30)
                        .fill(Color.red)
                        .frame(width: recording.isRecording ? 32 : 60,
                               height: recording.isRecording ? 32 : 60)
                        .animation(.easeInOut(duration: 0.2), value: recording.isRecording)
                }
            }
            .accessibilityLabel(recording.isRecording ? "Stop recording" : "Start recording")
        }
        .padding(.bottom, 8)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
