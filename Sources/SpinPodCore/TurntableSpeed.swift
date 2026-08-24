import Foundation

public enum TurntableSpeed: String, CaseIterable, Sendable {
    case rpm33 = "33 ⅓"
    case rpm45 = "45"
    case rpm78 = "78"

    public var rpm: Double {
        switch self {
        case .rpm33: return 100.0 / 3.0
        case .rpm45: return 45
        case .rpm78: return 78
        }
    }

    public static func nearest(to rpm: Double) -> TurntableSpeed {
        allCases.min { abs($0.rpm - rpm) < abs($1.rpm - rpm) } ?? .rpm33
    }

    public func errorPercent(measuredRPM: Double) -> Double {
        (measuredRPM - rpm) / rpm * 100
    }
}

