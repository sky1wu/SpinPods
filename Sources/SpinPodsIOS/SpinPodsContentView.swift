import SpinPodsCore
import SwiftUI
import UIKit

struct SpinPodsContentView: View {
    @ObservedObject var monitor: HeadphoneMotionMonitor

    private let targetTolerancePercent = 1.0
    private let mainVerticalPadding: CGFloat = 28

    @AppStorage("didConfirmAutomaticEarDetectionDisabled")
    private var didConfirmAutomaticEarDetectionDisabled = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var targetSpeed: TurntableSpeed = .rpm33
    @State private var selectedAirPodSide: AirPodSide = .left
    @State private var isShowingSetup = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 26) {
                        connectionStatus
                        rpmReading
                        targetComparison
                        speedTrend
                        measurementOptions
                        measurementButton
                        preparationReminder
                    }
                    .frame(maxWidth: 560)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Swift.max(
                            geometry.size.height - mainVerticalPadding * 2,
                            0
                        ),
                        alignment: .center
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, mainVerticalPadding)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Color(.systemBackground))
            .navigationTitle("SpinPods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("测量前准备", systemImage: "info.circle") {
                        isShowingSetup = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .tint(.blue)
        .onAppear {
            isShowingSetup = !didConfirmAutomaticEarDetectionDisabled
            updateIdleTimer(isMeasuring: monitor.isMeasuring)
        }
        .onDisappear {
            updateIdleTimer(isMeasuring: monitor.isMeasuring)
        }
        .onChange(of: monitor.isMeasuring) { _, isMeasuring in
            updateIdleTimer(isMeasuring: isMeasuring)
        }
        .onChange(of: selectedAirPodSide) { _, _ in
            if !monitor.isMeasuring && monitor.hasSamples {
                monitor.clearSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                monitor.refreshAvailability()
                updateIdleTimer(isMeasuring: monitor.isMeasuring)
            } else {
                updateIdleTimer(isMeasuring: false)
                if monitor.isMeasuring {
                    monitor.stopMeasuring()
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingSetup) {
            MeasurementSetupView {
                didConfirmAutomaticEarDetectionDisabled = true
                isShowingSetup = false
                monitor.refreshAvailability()
            }
            .interactiveDismissDisabled()
        }
    }

    private var connectionStatus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(monitor.state.title)
                    .font(.subheadline.weight(.medium))

                if monitor.state == .unavailable || monitor.state == .disconnected {
                    Button("重新检查") {
                        monitor.refreshAvailability()
                    }
                    .font(.subheadline)
                }
            }

            if shouldShowStatusDetail {
                Text(monitor.state.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rpmReading: some View {
        VStack(spacing: 8) {
            Text(displayedRPM)
                .font(.system(size: 88, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("RPM")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            readingState
                .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var readingState: some View {
        if let reading = monitor.reading {
            Label(
                reading.isStable
                    ? "读数稳定 · 波动 \(formattedDeviation(reading.standardDeviationRPM)) RPM"
                    : "正在等待稳定读数",
                systemImage: reading.isStable ? "checkmark.circle.fill" : "waveform.path"
            )
            .font(.subheadline)
            .foregroundStyle(reading.isStable ? .green : .secondary)
        } else if monitor.isMeasuring {
            ProgressView("正在等待 AirPods 数据")
                .font(.subheadline)
        } else {
            Text("准备测量")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var airPodSidePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("使用的 AirPod")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("测量耳机", selection: $selectedAirPodSide) {
                ForEach(AirPodSide.allCases) { side in
                    Text(side.title).tag(side)
                }
            }
            .pickerStyle(.segmented)
            .disabled(monitor.isMeasuring)
        }
        .frame(maxWidth: 300)
    }

    private var targetComparison: some View {
        VStack(spacing: 6) {
            if let assessment {
                Label(comparisonTitle(for: assessment), systemImage: comparisonSymbol(for: assessment))
                    .font(.headline)
                    .foregroundStyle(comparisonColor(for: assessment))
                Text(
                    "当前 − 目标 \(signed(assessment.differenceRPM, fractionLength: 2)) RPM"
                        + " · \(signed(assessment.differencePercent, fractionLength: 2))%"
                )
                .font(.subheadline.monospacedDigit())
            }

            Text(acceptableRangeDescription)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var speedTrend: some View {
        VStack(spacing: 10) {
            HStack {
                Text("转速趋势")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("绿色区间 ±\(targetTolerancePercent.formatted(.number))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            RPMTrendChart(
                values: monitor.rpmHistory,
                targetRPM: targetSpeed.rpm,
                tolerancePercent: targetTolerancePercent
            )
            .frame(height: 126)
        }
    }

    private var measurementOptions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                targetSpeedPicker
                airPodSidePicker
            }
            VStack(spacing: 18) {
                targetSpeedPicker
                airPodSidePicker
            }
        }
    }

    private var targetSpeedPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("目标转速")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("目标转速", selection: $targetSpeed) {
                ForEach(TurntableSpeed.allCases, id: \.self) { speed in
                    Text(speed.rawValue).tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private var measurementButton: some View {
        if monitor.isMeasuring {
            Button {
                monitor.stopMeasuring()
            } label: {
                Label("停止测量", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(.red)
            .frame(maxWidth: 300)
        } else {
            Button {
                monitor.startMeasuring(airPodSide: selectedAirPodSide)
            } label: {
                Label("开始测量", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!canStartMeasurement)
            .frame(maxWidth: 300)
        }
    }

    private var preparationReminder: some View {
        Label {
            Text("测量前确认已关闭自动人耳检测，并将 AirPod 固定在靠近圆心的位置。")
                .multilineTextAlignment(.center)
        } icon: {
            Image(systemName: "checkmark.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: 420)
    }

    private var displayedRPM: String {
        guard let reading = monitor.reading else { return "—" }
        return reading.smoothedRPM.formatted(.number.precision(.fractionLength(2)))
    }

    private var assessment: SpeedAssessment? {
        guard let reading = monitor.reading else { return nil }
        return targetSpeed.assess(
            measuredRPM: reading.smoothedRPM,
            tolerancePercent: targetTolerancePercent
        )
    }

    private var acceptableRangeDescription: String {
        let range = targetSpeed.assess(
            measuredRPM: targetSpeed.rpm,
            tolerancePercent: targetTolerancePercent
        )
        let target = targetSpeed.rpm.formatted(.number.precision(.fractionLength(2)))
        let lower = range.lowerBoundRPM.formatted(.number.precision(.fractionLength(2)))
        let upper = range.upperBoundRPM.formatted(.number.precision(.fractionLength(2)))
        return "目标 \(target) RPM · 可接受 \(lower)–\(upper) RPM"
    }

    private var canStartMeasurement: Bool {
        monitor.state == .ready && didConfirmAutomaticEarDetectionDisabled
    }

    private var shouldShowStatusDetail: Bool {
        switch monitor.state {
        case .denied, .unavailable, .disconnected, .failed:
            return true
        case .idle, .ready, .measuring:
            return false
        }
    }

    private var statusColor: Color {
        switch monitor.state {
        case .ready: return .blue
        case .measuring: return .green
        case .failed, .denied: return .red
        case .unavailable, .disconnected: return .orange
        case .idle: return .secondary
        }
    }

    private func formattedDeviation(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)))
    }

    private func comparisonTitle(for assessment: SpeedAssessment) -> String {
        switch assessment.status {
        case .withinRange: return "目标范围内"
        case .tooSlow: return "转速过慢"
        case .tooFast: return "转速过快"
        }
    }

    private func comparisonSymbol(for assessment: SpeedAssessment) -> String {
        switch assessment.status {
        case .withinRange: return "checkmark.circle.fill"
        case .tooSlow: return "arrow.down.circle.fill"
        case .tooFast: return "arrow.up.circle.fill"
        }
    }

    private func comparisonColor(for assessment: SpeedAssessment) -> Color {
        assessment.status == .withinRange ? .green : .orange
    }

    private func signed(_ value: Double, fractionLength: Int) -> String {
        let sign = value >= 0 ? "+" : "−"
        let magnitude = abs(value).formatted(
            .number.precision(.fractionLength(fractionLength))
        )
        return sign + magnitude
    }

    private func updateIdleTimer(isMeasuring: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isMeasuring
    }
}

private struct MeasurementSetupView: View {
    let confirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: "airpods")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(.blue)
                        Text("测量前准备")
                            .font(.largeTitle.bold())
                        Text("三个步骤，确保 AirPod 能在离耳状态持续提供运动数据。")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 24) {
                        setupStep(
                            number: 1,
                            title: "关闭自动人耳检测",
                            detail: "打开“设置 → 蓝牙”，点按 AirPods 右侧的 ⓘ，关闭“自动人耳检测”。"
                        )
                        setupStep(
                            number: 2,
                            title: "选择并固定一侧耳机",
                            detail: "先停止转盘，再用可移除胶泥或软质固定座将耳机固定。"
                        )
                        setupStep(
                            number: 3,
                            title: "尽量靠近转盘圆心",
                            detail: "确认耳机不会滑落后，再启动转盘。"
                        )
                    }
                    .frame(maxWidth: 560, alignment: .leading)

                    Text("SpinPods 无法读取“自动人耳检测”开关状态，需要你自行确认。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        confirm()
                    } label: {
                        Text("我已完成准备")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .frame(maxWidth: 320)
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
        }
    }

    private func setupStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "\(number).circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
