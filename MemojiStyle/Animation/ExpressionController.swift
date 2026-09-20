import Foundation

/// Smooths and conditions the per-channel expression values before they reach
/// the rig driver (Phase 5). Keeps one `ScalarSmoother` per channel so each
/// facial control has its own stable, responsive filter.
final class ExpressionController {
    private var smoothers: [AvatarChannel: ScalarSmoother] = [:]

    /// Returns conditioned + smoothed values for every channel present.
    func process(_ channels: [AvatarChannel: Float],
                 params: SmoothingParameters) -> [AvatarChannel: Float] {
        var output: [AvatarChannel: Float] = [:]
        output.reserveCapacity(channels.count)

        for (channel, raw) in channels {
            let conditioned = SmoothingMath.conditionExpression(raw, params: params)
            let smoothing = smoothingWeight(for: channel, params: params)
            var smoother = smoothers[channel] ?? ScalarSmoother()
            let value = smoother.update(target: conditioned, smoothing: smoothing)
            smoothers[channel] = smoother
            output[channel] = value
        }
        return output
    }

    /// Different facial regions want different responsiveness.
    private func smoothingWeight(for channel: AvatarChannel,
                                 params: SmoothingParameters) -> Float {
        switch channel {
        case .eyeBlinkLeft, .eyeBlinkRight:
            // Blinks must be crisp — smooth the least.
            return params.mouthSmoothing * 0.4
        case .jawOpen, .mouthSmileLeft, .mouthSmileRight,
             .mouthFunnel, .mouthPucker, .mouthLeft, .mouthRight, .mouthClose:
            return params.mouthSmoothing
        case .eyeLookInLeft, .eyeLookInRight, .eyeLookOutLeft, .eyeLookOutRight,
             .eyeLookUpLeft, .eyeLookUpRight, .eyeLookDownLeft, .eyeLookDownRight:
            return params.eyeSmoothing
        default:
            return params.expressionSmoothing
        }
    }
}
