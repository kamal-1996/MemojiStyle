import SwiftUI

/// Developer overlay: FPS, thermal state, memory, and the active capture config
/// (Phase 11 / 14). Toggle off in Settings for clean recordings.
struct DebugView: View {
    @ObservedObject var performance: PerformanceMonitor
    let fps: Double
    let config: CaptureConfiguration?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                pill(String(format: "FPS %.0f", fps))
                pill("Thermal: \(performance.thermalLabel)", warn: performance.thermalState.rawValue >= 2)
                pill(String(format: "Mem %.0f MB", performance.memoryMB))
            }
            if let config = config {
                Text(config.summary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(_ text: String, warn: Bool = false) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundColor(warn ? .yellow : .white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.55), in: Capsule())
    }
}
