import Foundation
import SpinPodsCore
import SwiftUI
import UniformTypeIdentifiers

struct SpinPodsContentView: View {
    @ObservedObject var monitor: HeadphoneMotionMonitor

    @AppStorage("didConfirmAutomaticEarDetectionDisabled")
    private var didConfirmAutomaticEarDetectionDisabled = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var targetSpeed: TurntableSpeed = .rpm33
    @State private var selectedAirPodSide: AirPodSide = .left
    @State private var isShowingSetup = false
    @State private var isExporting = false
    @State private var exportDocument: CSVFileDocument?
    @State private var exportError: String?

    private var measuredRPM: Double { monitor.reading?.smoothedRPM ?? 0 }
    private var rawRPM: Double { monitor.reading?.rawRPM ?? 0 }
    private var errorPercent: Double { targetSpeed.errorPercent(measuredRPM: measuredRPM) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    statusPanel
                    automaticEarDetectionNotice
                    measurementPanel
                    safetyNotice
                }
                .frame(maxWidth: 900)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SpinPods")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.indigo)
        .onAppear {
            isShowingSetup = !didConfirmAutomaticEarDetectionDisabled
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
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result {
                exportError = error.localizedDescription
            }
            exportDocument = nil
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好") { exportError = nil }
        } message: {
            Text(exportError ?? "未知错误")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AirPods 黑胶转速计")
                    .font(.title2.bold())
                Text("将固定好的单只 AirPod 靠近转盘圆心放置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    targetSpeedPicker
                    airPodSidePicker
                }
                VStack(spacing: 12) {
                    targetSpeedPicker
                    airPodSidePicker
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var targetSpeedPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("标称转速")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("标称转速", selection: $targetSpeed) {
                ForEach(TurntableSpeed.allCases, id: \.self) { speed in
                    Text(speed.rawValue).tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity)
    }

    private var airPodSidePicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("本次使用")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("测量耳机", selection: $selectedAirPodSide) {
                ForEach(AirPodSide.allCases) { side in
                    Text(side.title).tag(side)
                }
            }
            .pickerStyle(.segmented)
            .disabled(monitor.isMeasuring || monitor.hasSamples)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                statusDescription
                Spacer(minLength: 12)
                statusActions
            }
            VStack(alignment: .leading, spacing: 14) {
                statusDescription
                statusActions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusDescription: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .shadow(color: statusColor.opacity(0.45), radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(monitor.state.title)
                    .font(.headline)
                Text(monitor.state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusActions: some View {
        HStack(spacing: 10) {
            if monitor.state == .unavailable || monitor.state == .disconnected {
                Button("重新检查") { monitor.refreshAvailability() }
                    .buttonStyle(.bordered)
            }
            Button(monitor.isMeasuring ? "停止" : "开始测量") {
                if monitor.isMeasuring {
                    monitor.stopMeasuring()
                } else {
                    monitor.startMeasuring(airPodSide: selectedAirPodSide)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canToggleMeasurement)
        }
    }

    private var automaticEarDetectionNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "ear")
                .font(.title3)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("离耳测量必须关闭“自动人耳检测”")
                    .font(.headline)
                Text("SpinPods 无法读取这个系统开关；每次测量前请自行确认。开启时 AirPod 离耳后不会上报运动数据。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("查看步骤") { isShowingSetup = true }
                .font(.callout)
        }
        .padding(14)
        .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        }
    }

    private var measurementPanel: some View {
        VStack(spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    rpmValue
                    Spacer(minLength: 12)
                    readingSummary
                }
                VStack(alignment: .leading, spacing: 12) {
                    rpmValue
                    readingSummary
                }
            }

            RPMHistoryView(values: monitor.rpmHistory, targetRPM: targetSpeed.rpm)
                .frame(height: 120)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                MetricCard(
                    label: "相对标称",
                    value: measuredRPM == 0
                        ? "—"
                        : errorPercent.formatted(.number.precision(.fractionLength(2))) + "%",
                    tint: abs(errorPercent) <= 1 && measuredRPM > 0 ? .green : .orange
                )
                MetricCard(
                    label: "波动 σ",
                    value: (monitor.reading?.standardDeviationRPM).map {
                        $0.formatted(.number.precision(.fractionLength(3))) + " RPM"
                    } ?? "—",
                    tint: .blue
                )
                MetricCard(
                    label: "采样率",
                    value: monitor.sampleRateHz > 0
                        ? monitor.sampleRateHz.formatted(.number.precision(.fractionLength(1))) + " Hz"
                        : "—",
                    tint: .purple
                )
                MetricCard(label: "样本", value: monitor.sampleCount.formatted(), tint: .indigo)
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack {
                    sensorDescription
                    Spacer(minLength: 8)
                    sessionActionButtons
                }
                VStack(alignment: .leading, spacing: 10) {
                    sensorDescription
                    HStack {
                        Spacer()
                        sessionActionButtons
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var rpmValue: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(measuredRPM, format: .number.precision(.fractionLength(2)))
                .font(.system(size: 62, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text("RPM · 滤波值")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var readingSummary: some View {
        VStack(alignment: .trailing, spacing: 8) {
            stabilityBadge
            Text("瞬时值 \(rawRPM, format: .number.precision(.fractionLength(2))) RPM")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            if let side = monitor.sessionAirPodSide {
                Text("数据来源：\(side.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sensorDescription: some View {
        let rate = monitor.latestRotationRate
        return Text(String(
            format: "陀螺仪 x %+.3f  y %+.3f  z %+.3f  |ω| %.3f",
            rate.x,
            rate.y,
            rate.z,
            rate.magnitude
        ))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var sessionActionButtons: some View {
        HStack(spacing: 10) {
            Button("清空") { monitor.clearSession() }
                .disabled(!monitor.hasSamples)
            Button("导出 CSV") { exportCSV() }
                .disabled(!monitor.hasSamples)
        }
    }

    private var safetyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            Text("先停止转盘，将单只 AirPod 用可移除胶泥或软质固定座牢固固定并尽量靠近圆心，再启动转盘。同一组测量始终使用同一侧耳机。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var stabilityBadge: some View {
        let stable = monitor.reading?.isStable == true
        return Label(
            stable ? "读数稳定" : "等待稳定",
            systemImage: stable ? "checkmark.circle.fill" : "waveform.path"
        )
        .font(.callout.weight(.semibold))
        .foregroundStyle(stable ? .green : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((stable ? Color.green : Color.secondary).opacity(0.1), in: Capsule())
    }

    private var canToggleMeasurement: Bool {
        monitor.isMeasuring
            || (monitor.state == .ready && didConfirmAutomaticEarDetectionDisabled)
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

    private var exportFilename: String {
        let side = monitor.sessionAirPodSide?.rawValue ?? selectedAirPodSide.rawValue
        return "spinpods-\(side)-measurement.csv"
    }

    private func exportCSV() {
        guard let data = monitor.csvData() else {
            exportError = "无法编码测量数据。"
            return
        }
        exportDocument = CSVFileDocument(data: data)
        isExporting = true
    }
}

private struct MeasurementSetupView: View {
    let confirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "airpods")
                        .font(.system(size: 54))
                        .foregroundStyle(.indigo)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("测量前准备")
                            .font(.largeTitle.bold())
                        Text("完成以下步骤后，AirPod 才能在离耳状态持续提供运动数据。")
                            .foregroundStyle(.secondary)
                    }

                    setupStep(
                        number: 1,
                        title: "关闭自动人耳检测",
                        detail: "打开“设置 → 蓝牙”，点按 AirPods 右侧的 ⓘ，关闭“自动人耳检测”。"
                    )
                    setupStep(
                        number: 2,
                        title: "选择并固定一侧耳机",
                        detail: "记录使用左耳或右耳；先停止转盘，再用可移除胶泥或软质固定座将耳机固定。"
                    )
                    setupStep(
                        number: 3,
                        title: "尽量靠近转盘圆心",
                        detail: "减小放置半径可降低偏心产生的离心加速度；确认不会滑落后再启动转盘。"
                    )

                    Text("SpinPods 无法通过公开 API 检查“自动人耳检测”是否已经关闭。点击下方按钮表示你已自行确认。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: 620)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button("我已关闭并完成固定") { confirm() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 620)
                    .padding()
                    .background(.bar)
            }
        }
    }

    private func setupStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number.formatted())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.indigo, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricCard: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct RPMHistoryView: View {
    let values: [Double]
    let targetRPM: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.035))

                if values.count < 2 {
                    Text("开始测量后显示转速趋势")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    let lowerBound = min(values.min() ?? targetRPM, targetRPM) - 1
                    let upperBound = max(values.max() ?? targetRPM, targetRPM) + 1
                    let range = max(upperBound - lowerBound, 1)
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let targetY = height * CGFloat(1 - (targetRPM - lowerBound) / range)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: targetY))
                        path.addLine(to: CGPoint(x: width, y: targetY))
                    }
                    .stroke(Color.orange.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                    Path { path in
                        for (index, value) in values.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                            let y = height * CGFloat(1 - (value - lowerBound) / range)
                            let point = CGPoint(x: x, y: y)
                            if index == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
            }
        }
        .accessibilityLabel("转速趋势")
    }
}
