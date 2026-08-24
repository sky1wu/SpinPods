import Combine
import CoreMotion
import Foundation
import SpinPodsCore

enum AirPodSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: Self { self }

    var title: String {
        switch self {
        case .left: return "左耳"
        case .right: return "右耳"
        }
    }
}

final class HeadphoneMotionMonitor: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case ready
        case measuring
        case unavailable
        case denied
        case disconnected
        case failed(String)

        var title: String {
            switch self {
            case .idle: return "正在检查 AirPods"
            case .ready: return "AirPods 已就绪"
            case .measuring: return "正在采样"
            case .unavailable: return "运动数据不可用"
            case .denied: return "运动权限被拒绝"
            case .disconnected: return "AirPods 已断开"
            case .failed: return "采样出错"
            }
        }

        var detail: String {
            switch self {
            case .idle:
                return "请确保支持空间音频的 AirPods 已连接到这台 Mac。"
            case .ready:
                return "开始前请关闭自动人耳检测并固定 AirPod，再启动转盘。"
            case .measuring:
                return "正在接收耳机 IMU 数据并计算转速。"
            case .unavailable:
                return "没有检测到兼容的耳机运动数据。请连接 AirPods 后重试。"
            case .denied:
                return "请在系统设置 → 隐私与安全性 → 运动与健身中允许 SpinPods。"
            case .disconnected:
                return "重新连接 AirPods 后，程序会再次检查。"
            case let .failed(message):
                return message
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var reading: RPMReading?
    @Published private(set) var sampleRateHz: Double = 0
    @Published private(set) var sampleCount = 0
    @Published private(set) var latestRotationRate = MotionVector(x: 0, y: 0, z: 0)
    @Published private(set) var rpmHistory: [Double] = []
    @Published private(set) var sessionAirPodSide: AirPodSide?

    var hasSamples: Bool { !recordedSamples.isEmpty }
    var isMeasuring: Bool { state == .measuring }

    private let motionManager = CMHeadphoneMotionManager()
    private var estimator = RPMEstimator()
    private var recordedSamples: [RecordedMotionSample] = []
    private var sessionStartTimestamp: TimeInterval?
    private var recentTimestamps: [TimeInterval] = []
    private var lastPublishedTimestamp: TimeInterval = -.infinity

    override init() {
        super.init()
        motionManager.delegate = self
        motionManager.startConnectionStatusUpdates()
        refreshAvailability()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopConnectionStatusUpdates()
    }

    func refreshAvailability() {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            state = .denied
        case .authorized, .notDetermined:
            state = motionManager.isDeviceMotionAvailable ? .ready : .unavailable
        @unknown default:
            state = .unavailable
        }
    }

    func startMeasuring(airPodSide: AirPodSide) {
        guard !isMeasuring else { return }

        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            state = .denied
            return
        case .authorized, .notDetermined:
            break
        @unknown default:
            state = .unavailable
            return
        }

        guard motionManager.isDeviceMotionAvailable else {
            state = .unavailable
            return
        }

        resetSession()
        sessionAirPodSide = airPodSide
        state = .measuring

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                self.stopAfterError(error)
                return
            }
            guard let motion else { return }
            self.consume(motion)
        }
    }

    func stopMeasuring() {
        motionManager.stopDeviceMotionUpdates()
        if state == .measuring {
            state = motionManager.isDeviceMotionAvailable ? .ready : .unavailable
        }
    }

    func clearSession() {
        stopMeasuring()
        resetSession()
        refreshAvailability()
    }

    func csvData() -> Data? {
        CSVEncoder.encode(recordedSamples, airPodSide: sessionAirPodSide).data(using: .utf8)
    }

    private func resetSession() {
        estimator.reset()
        recordedSamples.removeAll(keepingCapacity: true)
        recentTimestamps.removeAll(keepingCapacity: true)
        rpmHistory.removeAll(keepingCapacity: true)
        sessionStartTimestamp = nil
        lastPublishedTimestamp = -.infinity
        reading = nil
        sampleRateHz = 0
        sampleCount = 0
        latestRotationRate = MotionVector(x: 0, y: 0, z: 0)
        sessionAirPodSide = nil
    }

    private func consume(_ motion: CMDeviceMotion) {
        if sessionStartTimestamp == nil {
            sessionStartTimestamp = motion.timestamp
        }

        let rotationRate = MotionVector(
            x: motion.rotationRate.x,
            y: motion.rotationRate.y,
            z: motion.rotationRate.z
        )
        let estimate = estimator.add(
            rotationRateRadiansPerSecond: rotationRate,
            timestamp: motion.timestamp
        )
        let elapsed = motion.timestamp - (sessionStartTimestamp ?? motion.timestamp)
        recordedSamples.append(RecordedMotionSample(
            motion: motion,
            elapsedTime: elapsed,
            reading: estimate
        ))

        recentTimestamps.append(motion.timestamp)
        let rateWindowStart = motion.timestamp - 2
        recentTimestamps.removeAll { $0 < rateWindowStart }

        // Limit view invalidation to 10 Hz while retaining every raw sample for CSV.
        guard motion.timestamp - lastPublishedTimestamp >= 0.1 else { return }
        lastPublishedTimestamp = motion.timestamp
        reading = estimate
        latestRotationRate = rotationRate
        sampleCount = recordedSamples.count
        if let first = recentTimestamps.first, let last = recentTimestamps.last, last > first {
            sampleRateHz = Double(recentTimestamps.count - 1) / (last - first)
        }
        rpmHistory.append(estimate.smoothedRPM)
        if rpmHistory.count > 240 {
            rpmHistory.removeFirst(rpmHistory.count - 240)
        }
    }

    private func stopAfterError(_ error: Error) {
        motionManager.stopDeviceMotionUpdates()
        state = .failed(error.localizedDescription)
    }
}

extension HeadphoneMotionMonitor: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isMeasuring else { return }
            self.refreshAvailability()
        }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.motionManager.stopDeviceMotionUpdates()
            self.state = .disconnected
        }
    }
}
