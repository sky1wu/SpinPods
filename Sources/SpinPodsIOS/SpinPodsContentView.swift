import SpinPodsCore
import SwiftUI

struct SpinPodsContentView: View {
    @ObservedObject var monitor: HeadphoneMotionMonitor

    @AppStorage("didConfirmAutomaticEarDetectionDisabled")
    private var didConfirmAutomaticEarDetectionDisabled = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedAirPodSide: AirPodSide = .left
    @State private var isShowingSetup = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 32) {
                        connectionStatus
                        rpmReading
                        airPodSidePicker
                        measurementButton
                        preparationReminder
                    }
                    .frame(maxWidth: 520)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height,
                        alignment: .center
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
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
        }
        .onChange(of: selectedAirPodSide) { _, _ in
            if !monitor.isMeasuring && monitor.hasSamples {
                monitor.clearSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                monitor.refreshAvailability()
            } else if monitor.isMeasuring {
                monitor.stopMeasuring()
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
