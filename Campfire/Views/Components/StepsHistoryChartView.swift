import Charts
import SwiftUI

struct StepsHistoryChartView: View {
    var points: [StepChartPoint]
    var range: ProfileChartRange

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    var body: some View {
        if points.isEmpty {
            emptyChart
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("Date", point.date, unit: range.chartUnit),
                    y: .value("Steps", point.steps)
                )
                .foregroundStyle(AppTheme.Palette.ember)
                .cornerRadius(5)
            }
            .chartYScale(domain: 0...maxStepDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine()
                        .foregroundStyle(AppTheme.Palette.glassStroke.opacity(0.7))

                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Palette.creamMuted)
                }
            }
            .chartXAxis {
                AxisMarks(values: xAxisValues) { value in
                    AxisTick()
                        .foregroundStyle(AppTheme.Palette.creamMuted.opacity(0.38))

                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.creamMuted)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(AppTheme.Palette.navyInk.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(height: 190)
        }
    }

    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.Palette.emberGold)

            Text("Start walking to build your chart.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.creamMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(AppTheme.Palette.navyInk.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var maxStepDomain: Int {
        let maxSteps = points.map(\.steps).max() ?? 0
        let padded = Int(Double(maxSteps) * 1.18)
        return max(padded, 1_000)
    }

    private var xAxisValues: [Date] {
        switch range {
        case .week:
            return points.map(\.date)
        case .month:
            return points.enumerated().compactMap { index, point in
                index % 5 == 0 || index == points.count - 1 ? point.date : nil
            }
        case .year:
            return points.map(\.date)
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch range {
        case .week:
            return Self.weekdayFormatter.string(from: date)
        case .month:
            return Self.dayFormatter.string(from: date)
        case .year:
            return Self.monthFormatter.string(from: date)
        }
    }
}

#Preview("Steps History Chart") {
    ZStack {
        AppTheme.Palette.navyInk.ignoresSafeArea()
        StepsHistoryChartView(
            points: ProfileViewModel.preview().chartPoints,
            range: .week
        )
        .padding()
    }
}
