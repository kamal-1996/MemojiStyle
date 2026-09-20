import Foundation
import Combine

/// Lightweight runtime health readout (Phase 14).
///
/// Surfaces thermal state and memory footprint for the debug overlay so you can
/// see when the device is getting stressed during 4K/60 recording. FPS is
/// reported separately by `FaceTrackingManager`.
@MainActor
final class PerformanceMonitor: ObservableObject {

    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var memoryMB: Double = 0

    private var timer: Timer?

    func start() {
        thermalState = ProcessInfo.processInfo.thermalState
        NotificationCenter.default.addObserver(
            self, selector: #selector(thermalChanged),
            name: ProcessInfo.thermalStateDidChangeNotification, object: nil)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.memoryMB = PerformanceMonitor.usedMemoryMB() }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        NotificationCenter.default.removeObserver(self)
    }

    var thermalLabel: String {
        switch thermalState {
        case .nominal:  return "Nominal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    @objc private func thermalChanged() {
        Task { @MainActor in self.thermalState = ProcessInfo.processInfo.thermalState }
    }

    private static func usedMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
}
