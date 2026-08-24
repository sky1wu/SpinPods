import Foundation
import SpinPodsCore

private enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): return message
        }
    }
}

@main
struct SpinPodsCoreChecks {
    static func main() throws {
        let checks: [(String, () throws -> Void)] = [
            ("radians per second conversion", checkRadiansPerSecondConversion),
            ("orientation independence", checkOrientationIndependence),
            ("outlier rejection", checkOutlierRejection),
            ("rolling window expiry", checkRollingWindowExpiry),
            ("stability detection", checkStabilityDetection),
            ("standard speed matching", checkStandardSpeedMatching),
            ("target tolerance assessment", checkTargetToleranceAssessment)
        ]

        for (name, check) in checks {
            try check()
            print("✓ \(name)")
        }
        print("All \(checks.count) SpinPodsCore checks passed.")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String
    ) throws {
        guard condition() else { throw CheckFailure.failed(message()) }
    }

    private static func checkRadiansPerSecondConversion() throws {
        let expectedRPM = 100.0 / 3.0
        let radiansPerSecond = expectedRPM * 2 * .pi / 60
        let actual = RPMEstimator.radiansPerSecondToRPM(radiansPerSecond)
        try expect(abs(actual - expectedRPM) < 0.000_001, "Expected \(expectedRPM), got \(actual)")
    }

    private static func checkOrientationIndependence() throws {
        var xAxisEstimator = RPMEstimator()
        var diagonalEstimator = RPMEstimator()
        let speed = 2 * Double.pi
        let component = speed / sqrt(3)

        let xAxis = xAxisEstimator.add(
            rotationRateRadiansPerSecond: .init(x: speed, y: 0, z: 0),
            timestamp: 0
        )
        let diagonal = diagonalEstimator.add(
            rotationRateRadiansPerSecond: .init(x: component, y: component, z: component),
            timestamp: 0
        )

        try expect(abs(xAxis.rawRPM - diagonal.rawRPM) < 0.000_001, "Orientation changed RPM")
        try expect(abs(xAxis.rawRPM - 60) < 0.000_001, "Expected 60 RPM, got \(xAxis.rawRPM)")
    }

    private static func checkOutlierRejection() throws {
        var estimator = RPMEstimator(configuration: .init(minimumSamples: 5))
        let normalRate = (100.0 / 3.0) * 2 * .pi / 60
        var reading: RPMReading?

        for index in 0..<10 {
            let rate = index == 5 ? 9.0 : normalRate + Double(index % 3 - 1) * 0.002
            reading = estimator.add(
                rotationRateRadiansPerSecond: .init(x: 0, y: rate, z: 0),
                timestamp: Double(index) * 0.1
            )
        }

        let actual = reading?.smoothedRPM ?? 0
        try expect(abs(actual - 100.0 / 3.0) < 0.03, "Spike affected filtered RPM: \(actual)")
        try expect((reading?.standardDeviationRPM ?? .infinity) < 0.03, "Spike affected deviation")
    }

    private static func checkRollingWindowExpiry() throws {
        var estimator = RPMEstimator(configuration: .init(windowDuration: 1))
        let lowRate = 33.0 * 2 * .pi / 60
        let highRate = 45.0 * 2 * .pi / 60

        _ = estimator.add(
            rotationRateRadiansPerSecond: .init(x: lowRate, y: 0, z: 0),
            timestamp: 0
        )
        let result = estimator.add(
            rotationRateRadiansPerSecond: .init(x: highRate, y: 0, z: 0),
            timestamp: 2
        )

        try expect(abs(result.smoothedRPM - 45) < 0.000_001, "Expired sample still affected RPM")
        try expect(result.sampleCount == 1, "Expected one sample, got \(result.sampleCount)")
    }

    private static func checkStabilityDetection() throws {
        var estimator = RPMEstimator(configuration: .init(
            windowDuration: 2,
            minimumSamples: 5,
            minimumStableDuration: 0.4,
            stableStandardDeviation: 0.1
        ))
        let rate = 45.0 * 2 * .pi / 60
        var result: RPMReading?

        for index in 0..<5 {
            result = estimator.add(
                rotationRateRadiansPerSecond: .init(x: 0, y: 0, z: rate),
                timestamp: Double(index) * 0.1
            )
        }

        try expect(result?.isStable == true, "Steady samples were not marked stable")
    }

    private static func checkStandardSpeedMatching() throws {
        let speed = TurntableSpeed.nearest(to: 44.55)
        try expect(speed == .rpm45, "Expected 45 RPM speed")
        let error = speed.errorPercent(measuredRPM: 44.55)
        try expect(abs(error + 1) < 0.000_001, "Expected -1% error, got \(error)")
    }

    private static func checkTargetToleranceAssessment() throws {
        let center = TurntableSpeed.rpm45.assess(measuredRPM: 45, tolerancePercent: 1)
        try expect(abs(center.lowerBoundRPM - 44.55) < 0.000_001, "Unexpected lower bound")
        try expect(abs(center.upperBoundRPM - 45.45) < 0.000_001, "Unexpected upper bound")
        try expect(center.status == .withinRange, "Target speed should be in range")

        let upperBoundary = TurntableSpeed.rpm45.assess(
            measuredRPM: center.upperBoundRPM,
            tolerancePercent: 1
        )
        try expect(upperBoundary.status == .withinRange, "Tolerance boundary should be inclusive")

        let fast = TurntableSpeed.rpm45.assess(measuredRPM: 45.5, tolerancePercent: 1)
        try expect(fast.status == .tooFast, "45.5 RPM should be too fast")
        try expect(abs(fast.differenceRPM - 0.5) < 0.000_001, "Unexpected fast difference")

        let slow = TurntableSpeed.rpm45.assess(measuredRPM: 44.5, tolerancePercent: 1)
        try expect(slow.status == .tooSlow, "44.5 RPM should be too slow")
        try expect(abs(slow.differenceRPM + 0.5) < 0.000_001, "Unexpected slow difference")
    }
}
