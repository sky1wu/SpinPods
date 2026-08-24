import SwiftUI

struct RPMTrendChart: View {
    let values: [Double]
    let targetRPM: Double
    let tolerancePercent: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))

            Canvas { context, size in
                draw(in: &context, size: size)
            }

            if values.count < 2 {
                Text("开始测量后显示趋势")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("转速趋势，绿色区域为目标容差范围")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = verticalScale(height: size.height)
        let lowerTarget = targetRPM * (1 - tolerancePercent / 100)
        let upperTarget = targetRPM * (1 + tolerancePercent / 100)
        let upperY = scale.yPosition(for: upperTarget)
        let lowerY = scale.yPosition(for: lowerTarget)

        var toleranceBand = Path()
        toleranceBand.addRect(CGRect(
            x: 0,
            y: upperY,
            width: size.width,
            height: Swift.max(lowerY - upperY, 1)
        ))
        context.fill(toleranceBand, with: .color(Color.green.opacity(0.1)))

        var targetLine = Path()
        let targetY = scale.yPosition(for: targetRPM)
        targetLine.move(to: CGPoint(x: 0, y: targetY))
        targetLine.addLine(to: CGPoint(x: size.width, y: targetY))
        context.stroke(
            targetLine,
            with: .color(Color.secondary.opacity(0.6)),
            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
        )

        guard values.count >= 2 else { return }
        var trendLine = Path()
        for (index, value) in values.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let point = CGPoint(x: x, y: scale.yPosition(for: value))
            if index == 0 {
                trendLine.move(to: point)
            } else {
                trendLine.addLine(to: point)
            }
        }
        context.stroke(
            trendLine,
            with: .color(.blue),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }

    private func verticalScale(height: CGFloat) -> VerticalScale {
        let lowerTarget = targetRPM * (1 - tolerancePercent / 100)
        let upperTarget = targetRPM * (1 + tolerancePercent / 100)
        let minimumValue = Swift.min(values.min() ?? lowerTarget, lowerTarget)
        let maximumValue = Swift.max(values.max() ?? upperTarget, upperTarget)
        let measuredSpan = maximumValue - minimumValue
        let minimumSpan = Swift.max(targetRPM * 0.01, 0.2)
        let contentSpan = Swift.max(measuredSpan, minimumSpan)
        let graphMinimum = Swift.max(minimumValue - contentSpan * 0.16, 0)
        let graphMaximum = maximumValue + contentSpan * 0.16
        return VerticalScale(
            minimum: graphMinimum,
            range: Swift.max(graphMaximum - graphMinimum, 0.1),
            height: height
        )
    }

    private struct VerticalScale {
        let minimum: Double
        let range: Double
        let height: CGFloat

        func yPosition(for value: Double) -> CGFloat {
            height * CGFloat(1 - (value - minimum) / range)
        }
    }
}
