import AppKit
import SpinPodsCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var monitor: HeadphoneMotionMonitor
    @State private var targetSpeed: TurntableSpeed = .rpm33
    @State private var exportError: String?

    private var measuredRPM: Double { monitor.reading?.smoothedRPM ?? 0 }
    private var rawRPM: Double { monitor.reading?.rawRPM ?? 0 }
    private var errorPercent: Double { targetSpeed.errorPercent(measuredRPM: measuredRPM) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                statusPanel
                automaticEarDetectionNotice
                measurementPanel
                safetyNotice
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SpinPods")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("AirPods 转盘转速可行性验证器")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("标称转速", selection: $targetSpeed) {
                ForEach(TurntableSpeed.allCases, id: \.self) { speed in
                    Text("\(speed.rawValue) RPM").tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 310)
        }
    }

    private var statusPanel: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .shadow(color: statusColor.opacity(0.5), radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(monitor.state.title)
                    .font(.headline)
                Text(monitor.state.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if monitor.state == .unavailable || monitor.state == .disconnected {
                Button("重新检查") { monitor.refreshAvailability() }
            }
            Button(monitor.isMeasuring ? "停止" : "开始测量") {
                monitor.isMeasuring ? monitor.stopMeasuring() : monitor.startMeasuring()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canToggleMeasurement)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var measurementPanel: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(measuredRPM, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 66, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("RPM · 滤波值")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 8) {
                    stabilityBadge
                    Text("瞬时值 \(rawRPM, format: .number.precision(.fractionLength(2))) RPM")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            RPMHistoryView(values: monitor.rpmHistory, targetRPM: targetSpeed.rpm)
                .frame(height: 116)

            HStack(spacing: 12) {
                MetricCard(
                    label: "相对标称",
                    value: measuredRPM == 0 ? "—" : errorPercent.formatted(.number.precision(.fractionLength(2))) + "%",
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
                MetricCard(
                    label: "样本",
                    value: monitor.sampleCount.formatted(),
                    tint: .indigo
                )
            }

            Divider()

            HStack {
                Text("陀螺仪 rad/s")
                    .font(.callout.weight(.medium))
                Text(vectorDescription)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清空") { monitor.clearSession() }
                    .disabled(!monitor.hasSamples)
                Button("导出 CSV…") { exportCSV() }
                    .disabled(!monitor.hasSamples)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var automaticEarDetectionNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "ear")
                .font(.title3)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("离耳测量前必须关闭“自动人耳检测”")
                    .font(.headline)
                Text("打开系统设置 → 蓝牙 → AirPods 右侧的 ⓘ，关闭“自动人耳检测”。开启时，AirPod 离耳后不会上报运动数据。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        }
    }

    private var safetyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            Text("实测前请用可移除胶泥或软质固定座，把单只 AirPod 牢固固定并尽量靠近转盘圆心；先从 33 ⅓ RPM 开始。不要把未固定的耳机直接放到旋转中的转盘上。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var stabilityBadge: some View {
        let stable = monitor.reading?.isStable == true
        return Label(stable ? "读数稳定" : "等待稳定", systemImage: stable ? "checkmark.circle.fill" : "waveform.path")
            .font(.callout.weight(.semibold))
            .foregroundStyle(stable ? .green : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((stable ? Color.green : Color.secondary).opacity(0.1), in: Capsule())
    }

    private var canToggleMeasurement: Bool {
        monitor.isMeasuring || monitor.state == .ready
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

    private var vectorDescription: String {
        let rate = monitor.latestRotationRate
        return String(format: "x %+.3f   y %+.3f   z %+.3f   |ω| %.3f", rate.x, rate.y, rate.z, rate.magnitude)
    }

    private func exportCSV() {
        guard let data = monitor.csvData() else {
            exportError = "无法编码测量数据。"
            return
        }

        let panel = NSSavePanel()
        panel.title = "导出 SpinPods 测量数据"
        panel.nameFieldStringValue = "spinpods-measurement.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            exportError = error.localizedDescription
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
        Canvas { context, size in
            let allValues = values + [targetRPM]
            let minimum = max(0, (allValues.min() ?? 0) - 3)
            let maximum = max(minimum + 6, (allValues.max() ?? 50) + 3)

            func y(_ value: Double) -> CGFloat {
                size.height - CGFloat((value - minimum) / (maximum - minimum)) * size.height
            }

            var targetPath = Path()
            targetPath.move(to: CGPoint(x: 0, y: y(targetRPM)))
            targetPath.addLine(to: CGPoint(x: size.width, y: y(targetRPM)))
            context.stroke(targetPath, with: .color(.secondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

            guard values.count > 1 else { return }
            var line = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                let point = CGPoint(x: x, y: y(value))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            context.stroke(line, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topLeading) {
            Text("最近 24 秒 · 虚线为标称")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(8)
        }
    }
}
