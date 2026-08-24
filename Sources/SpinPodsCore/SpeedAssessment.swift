import Foundation

public struct SpeedAssessment: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case withinRange
        case tooSlow
        case tooFast
    }

    public let measuredRPM: Double
    public let targetRPM: Double
    public let tolerancePercent: Double

    public init(
        measuredRPM: Double,
        targetRPM: Double,
        tolerancePercent: Double = 1
    ) {
        self.measuredRPM = measuredRPM
        self.targetRPM = targetRPM
        self.tolerancePercent = max(tolerancePercent, 0)
    }

    public var differenceRPM: Double {
        measuredRPM - targetRPM
    }

    public var differencePercent: Double {
        guard targetRPM != 0 else { return 0 }
        return differenceRPM / targetRPM * 100
    }

    public var lowerBoundRPM: Double {
        targetRPM * (1 - tolerancePercent / 100)
    }

    public var upperBoundRPM: Double {
        targetRPM * (1 + tolerancePercent / 100)
    }

    public var status: Status {
        if measuredRPM < lowerBoundRPM {
            return .tooSlow
        }
        if measuredRPM > upperBoundRPM {
            return .tooFast
        }
        return .withinRange
    }
}
