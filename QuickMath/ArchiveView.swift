import SwiftUI
import Charts

/// Pro feature: waste saved history, streaks, and insights.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {

                        // Summary tiles
                        HStack(spacing: 12) {
                            MetricTile(value: "\(appModel.usedCount)", label: "Items Rescued")
                            MetricTile(value: "\(appModel.wastedCount)", label: "Wasted")
                            MetricTile(value: "\(appModel.savedThisWeek)", label: "This Week")
                        }
                        .padding(.horizontal, 16)

                        // Rescue rate bar
                        if appModel.usedCount + appModel.wastedCount > 0 {
                            rescueRateSection
                        }

                        // Weekly chart
                        weeklyChartSection

                        // Log history
                        if !appModel.logs.isEmpty {
                            logHistorySection
                        } else {
                            Text("No history yet. Start marking items used or wasted to track your impact.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(24)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Waste Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rescue Rate

    private var rescueRateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rescue Rate")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 16)

            let total = Double(appModel.usedCount + appModel.wastedCount)
            let rate = total > 0 ? Double(appModel.usedCount) / total : 0

            VStack(spacing: 6) {
                HStack {
                    Text("\(Int(rate * 100))% rescued")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.qmAccent)
                    Spacer()
                    Text("\(appModel.wastedCount) wasted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.qmWrong.opacity(0.25))
                            .frame(height: 10)
                        Capsule()
                            .fill(Color.qmCorrect)
                            .frame(width: geo.size.width * rate, height: 10)
                    }
                }
                .frame(height: 10)
            }
            .qmCard()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 7 Days")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 16)

            Chart(weeklyData, id: \.day) { point in
                BarMark(
                    x: .value("Day", point.day),
                    y: .value("Items", point.rescued)
                )
                .foregroundStyle(Color.qmAccent)
            }
            .frame(height: 140)
            .qmCard()
            .padding(.horizontal, 16)
        }
    }

    private struct DayPoint { var day: String; var rescued: Int }

    private var weeklyData: [DayPoint] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return (0..<7).reversed().map { offset -> DayPoint in
            let date = cal.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let count = appModel.logs.filter {
                $0.action == "used" && cal.isDate($0.date, inSameDayAs: date)
            }.count
            return DayPoint(day: fmt.string(from: date), rescued: count)
        }
    }

    // MARK: - Log History

    private var logHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 16)

            ForEach(Array(appModel.logs.prefix(30))) { log in
                HStack(spacing: 12) {
                    Image(systemName: log.action == "used" ? "checkmark.circle.fill" : "trash.fill")
                        .foregroundStyle(log.action == "used" ? Color.qmCorrect : Color.qmWrong)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.fridgeItemName.capitalized)
                            .font(.subheadline.weight(.medium))
                        Text(log.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(log.action == "used" ? "Rescued" : "Wasted")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(log.action == "used" ? Color.qmCorrect : Color.qmWrong)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }
}
