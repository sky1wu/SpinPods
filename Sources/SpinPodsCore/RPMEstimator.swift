import Foundation

public struct RPMReading: Equatable, Sendable {
    public let timestamp: TimeInterval
    public let rawRPM: Double
    public let smoothedRPM: Double
    public let standardDeviationRPM: Double
    public let sampleCount: Int
    public let isStable: Bool
}

/// Estimates platter speed from the magnitude of the headphone gyroscope vector.
///
/// Using the magnitude makes the estimate independent of how an AirPod is oriented
/// on the platter. A rolling median and median-absolute-deviation filter reject
/// occasional motion spikes.
public struct RPMEstimator: Sendable {
    public struct Configuration: Equatable, Sendable {
        public var windowDuration: TimeInterval
        public var minimumSamples: Int
        public var minimumStableDuration: TimeInterval
        public var stableStandardDeviation: Double
        public var maximumRPM: Double

        public init(
            windowDuration: TimeInterval = 1.5,
            minimumSamples: Int = 20,
            minimumStableDuration: TimeInterval = 0.75,
            stableStandardDeviation: Double = 0.35,
            maximumRPM: Double = 100
        ) {
            self.windowDuration = windowDuration
            self.minimumSamples = minimumSamples
            self.minimumStableDuration = minimumStableDuration
            self.stableStandardDeviation = stableStandardDeviation
            self.maximumRPM = maximumRPM
        }
    }

    private struct Sample: Sendable {
        let timestamp: TimeInterval
        let rpm: Double
    }

    public private(set) var configuration: Configuration
    private var samples: [Sample] = []

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    /// Adds one gyroscope sample. Core Motion rotation rates are radians per second.
    @discardableResult
    public mutating func add(
        rotationRateRadiansPerSecond rate: MotionVector,
        timestamp: TimeInterval
    ) -> RPMReading {
        let rawRPM = min(Self.radiansPerSecondToRPM(rate.magnitude), configuration.maximumRPM)
        samples.append(Sample(timestamp: timestamp, rpm: rawRPM))

        let oldestAllowedTimestamp = timestamp - configuration.windowDuration
        samples.removeAll { $0.timestamp < oldestAllowedTimestamp }

        let filteredRPMs = rejectOutliers(samples.map(\.rpm))
        let smoothedRPM = median(filteredRPMs)
        let deviation = standardDeviation(filteredRPMs, around: smoothedRPM)
        let duration = (samples.last?.timestamp ?? timestamp) - (samples.first?.timestamp ?? timestamp)
        let stable = filteredRPMs.count >= configuration.minimumSamples
            && duration >= configuration.minimumStableDuration
            && deviation <= configuration.stableStandardDeviation

        return RPMReading(
            timestamp: timestamp,
            rawRPM: rawRPM,
            smoothedRPM: smoothedRPM,
            standardDeviationRPM: deviation,
            sampleCount: filteredRPMs.count,
            isStable: stable
        )
    }

    public static func radiansPerSecondToRPM(_ radiansPerSecond: Double) -> Double {
        abs(radiansPerSecond) * 60 / (2 * .pi)
    }

    private func rejectOutliers(_ values: [Double]) -> [Double] {
        guard values.count >= 5 else { return values }

        let center = median(values)
        let absoluteDeviations = values.map { abs($0 - center) }
        let mad = median(absoluteDeviations)
        guard mad > 0.000_001 else { return values }

        // 1.4826 scales MAD to the standard deviation of a normal distribution.
        let cutoff = 3.5 * 1.4826 * mad
        let filtered = values.filter { abs($0 - center) <= cutoff }
        return filtered.isEmpty ? values : filtered
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }

    private func standardDeviation(_ values: [Double], around center: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let variance = values.reduce(0) { partial, value in
            let difference = value - center
            return partial + difference * difference
        } / Double(values.count)
        return sqrt(variance)
    }
}

