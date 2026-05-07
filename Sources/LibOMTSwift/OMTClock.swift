import Foundation

public struct OMTClock: Sendable {
    private let startsAt: ContinuousClock.Instant

    public init() {
        self.startsAt = ContinuousClock.now
    }

    public var timestamp: Int64 {
        let elapsed = startsAt.duration(to: .now)
        let seconds = Double(elapsed.components.seconds)
        let attoseconds = Double(elapsed.components.attoseconds) / 1.0e18
        return Int64((seconds + attoseconds) * 10_000_000)
    }
}
