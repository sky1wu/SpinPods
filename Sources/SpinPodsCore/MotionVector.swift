import Foundation

/// A framework-independent three-dimensional vector used by the RPM estimator.
public struct MotionVector: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }
}

