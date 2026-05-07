import Foundation

public struct OMTClock: Sendable {
    private var startsAt: ContinuousClock.Instant
    private var lastTimestamp: Int64 = -1
    private var clockTimestamp: Int64 = -1
    private var frameRateNumerator: Int32 = -1
    private var frameRateDenominator: Int32 = -1
    private var sampleRate: Int32 = -1
    private var frameInterval: Int64 = -1
    private var audio: Bool

    public init(audio: Bool = false) {
        self.startsAt = ContinuousClock.now
        self.audio = audio
    }

    public var timestamp: Int64 {
        let elapsed = startsAt.duration(to: .now)
        let seconds = Double(elapsed.components.seconds)
        let attoseconds = Double(elapsed.components.attoseconds) / 1.0e18
        return Int64((seconds + attoseconds) * 10_000_000)
    }

    public mutating func process(_ frame: inout OMTMediaFrame) {
        if audio, frame.sampleRate != sampleRate {
            reset(frame)
        } else if frame.frameRateNumerator != frameRateNumerator || frame.frameRateDenominator != frameRateDenominator {
            reset(frame)
        }

        if frame.timestamp == -1 {
            if lastTimestamp == -1 {
                reset(frame)
                frame.timestamp = 0
            } else {
                if audio, sampleRate > 0, frame.samplesPerChannel > 0 {
                    frameInterval = 10_000_000 * Int64(frame.samplesPerChannel) / Int64(sampleRate)
                }
                frame.timestamp = lastTimestamp + frameInterval
                clockTimestamp += frameInterval

                var diff = clockTimestamp - timestamp
                while diff < -frameInterval {
                    frame.timestamp += frameInterval
                    clockTimestamp += frameInterval
                    diff += frameInterval
                }
                while clockTimestamp > timestamp {
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        }
        lastTimestamp = frame.timestamp
    }

    public mutating func Process(_ frame: inout OMTMediaFrame) {
        process(&frame)
    }

    private mutating func reset(_ frame: OMTMediaFrame) {
        frameRateDenominator = frame.frameRateDenominator
        frameRateNumerator = frame.frameRateNumerator
        sampleRate = frame.sampleRate
        if frame.frameRate > 0 {
            frameInterval = Int64(10_000_000 / frame.frameRate)
        }
        startsAt = ContinuousClock.now
        clockTimestamp = 0
    }
}
