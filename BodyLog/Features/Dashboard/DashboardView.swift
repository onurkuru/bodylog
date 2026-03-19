import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @Query private var settingsArray: [UserSettings]
    @State private var viewModel = DashboardViewModel()
    @State private var selectedRange: ChartRange = .month

    private var settings: UserSettings? { settingsArray.first }
    private var unit: WeightUnit { settings?.unitPreference ?? .kg }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: BLTheme.spacingLG) {
                    header.padding(.top, BLTheme.spacingSM)
                    weightEntryCard
                    let streak = viewModel.calculateStreak(from: entries)
                    if streak > 0 { streakCard(streak: streak) }
                    chartCard
                    statsRow
                    let recent = viewModel.recentEntries(from: entries)
                    if !recent.isEmpty { recentSection(entries: recent) }
                }
                .padding(.horizontal, BLTheme.spacingMD)
                .padding(.bottom, BLTheme.spacingXL)
            }
        }
        .onChange(of: entries.count) { updateWidgetData() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Dashboard")
                .font(BLTheme.headlineSerif(28))
                .foregroundStyle(BLTheme.textPrimary)
            Spacer()
            BLCircleButton(icon: "plus", filled: true) {
                appViewModel.showAddWeight()
            }
        }
    }

    // MARK: - Weight Entry Card

    private var weightEntryCard: some View {
        let hasToday = viewModel.hasEntryToday(entries: entries)

        return Button { appViewModel.showAddWeight() } label: {
            BLCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(hasToday ? "Today's weight" : "Log today's weight")
                            .font(BLTheme.caption())
                            .foregroundStyle(BLTheme.textSecondary)
                        if let weight = entries.first?.weight {
                            Text(weight.formattedWithUnit(unit))
                                .font(BLTheme.numberDisplay(36))
                                .foregroundStyle(BLTheme.textPrimary)
                        } else {
                            Text("Tap to start")
                                .font(BLTheme.titleSerif(22))
                                .foregroundStyle(BLTheme.accent)
                        }
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(hasToday ? BLTheme.success.opacity(0.15) : BLTheme.accentLight)
                            .frame(width: 48, height: 48)
                        Image(systemName: hasToday ? "checkmark" : "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(hasToday ? BLTheme.success : BLTheme.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak

    private func streakCard(streak: Int) -> some View {
        Button { appViewModel.activeSheet = .streakDetail } label: {
            BLCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(BLTheme.streak.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: "flame.fill").foregroundStyle(BLTheme.streak)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streak) day streak").font(BLTheme.bodyBold()).foregroundStyle(BLTheme.textPrimary)
                        Text("Keep it going!").font(BLTheme.caption()).foregroundStyle(BLTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(BLTheme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart

    private var chartCard: some View {
        let chartPoints = viewModel.chartPoints(from: entries, range: selectedRange)

        return BLCard {
            VStack(alignment: .leading, spacing: BLTheme.spacingMD) {
                HStack(spacing: 0) {
                    ForEach(ChartRange.allCases) { range in
                        Button {
                            if range == .allTime && !entitlementManager.isPro {
                                appViewModel.showPaywall(trigger: .allTimeChart)
                            } else { selectedRange = range }
                        } label: {
                            HStack(spacing: 4) {
                                Text(range.rawValue)
                                if range == .allTime && !entitlementManager.isPro {
                                    Image(systemName: "lock.fill").font(.system(size: 9))
                                }
                            }
                            .font(BLTheme.bodyBold(14))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedRange == range ? BLTheme.accent : Color.clear)
                            .foregroundStyle(selectedRange == range ? .white : BLTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))
                        }
                    }
                }
                .padding(4)
                .background(BLTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))

                if chartPoints.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 32)).foregroundStyle(BLTheme.textTertiary)
                        Text("Log your first weight\nto see the chart").font(BLTheme.body(14)).foregroundStyle(BLTheme.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(height: 180).frame(maxWidth: .infinity)
                } else {
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Weight", unit == .lbs ? point.weight.toLbs : point.weight))
                            .interpolationMethod(.catmullRom).foregroundStyle(BLTheme.accent).lineStyle(StrokeStyle(lineWidth: 2.5))
                        AreaMark(x: .value("Date", point.date), y: .value("Weight", unit == .lbs ? point.weight.toLbs : point.weight))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [BLTheme.accent.opacity(0.2), BLTheme.accent.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        PointMark(x: .value("Date", point.date), y: .value("Weight", unit == .lbs ? point.weight.toLbs : point.weight))
                            .symbolSize(chartPoints.count <= 14 ? 30 : 0).foregroundStyle(BLTheme.accent)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(BLTheme.textTertiary.opacity(0.3))
                            AxisValueLabel().font(BLTheme.caption(11)).foregroundStyle(BLTheme.textTertiary)
                        }
                    }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().font(BLTheme.caption(11)).foregroundStyle(BLTheme.textTertiary) } }
                    .frame(height: 180)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        let stats = viewModel.stats(from: entries, goalWeight: settings?.goalWeight)
        return HStack(spacing: 12) {
            statCard(title: "Current", value: stats.current?.formatted(unit: unit) ?? "—", suffix: stats.current != nil ? unit.rawValue : "")
            statCard(title: "Change", value: changeText(stats), suffix: stats.change != nil ? unit.rawValue : "", color: changeColor(stats))
            if let p = stats.goalProgress {
                statCard(title: "Goal", value: "\(Int(p * 100))", suffix: "%", color: p >= 1.0 ? BLTheme.success : BLTheme.accent)
            }
        }
    }

    private func statCard(title: String, value: String, suffix: String = "", color: Color = BLTheme.textPrimary) -> some View {
        BLCard {
            VStack(spacing: 4) {
                Text(title).font(BLTheme.caption(12)).foregroundStyle(BLTheme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(BLTheme.titleSerif(20)).foregroundStyle(color)
                    if !suffix.isEmpty && value != "—" { Text(suffix).font(BLTheme.caption(11)).foregroundStyle(BLTheme.textSecondary) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func changeText(_ stats: WeightStats) -> String {
        guard let c = stats.change else { return "—" }
        let v = unit == .lbs ? c.toLbs : c
        return "\(v > 0 ? "+" : "")\(String(format: "%.1f", v))"
    }

    private func changeColor(_ stats: WeightStats) -> Color {
        guard let c = stats.change else { return BLTheme.textPrimary }
        return c < 0 ? BLTheme.success : (c > 0 ? BLTheme.danger : BLTheme.textPrimary)
    }

    // MARK: - Recent

    private func recentSection(entries: [WeightEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent").font(BLTheme.titleSerif(20)).foregroundStyle(BLTheme.textPrimary)
            ForEach(entries) { entry in
                Button { appViewModel.showEditWeight(entry) } label: {
                    BLCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.date.relativeFormatted).font(BLTheme.bodyBold(15)).foregroundStyle(BLTheme.textPrimary)
                                if let note = entry.note, !note.isEmpty {
                                    Text(note).font(BLTheme.caption(13)).foregroundStyle(BLTheme.textSecondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            Text(entry.weight.formattedWithUnit(unit)).font(BLTheme.titleSerif(18)).foregroundStyle(BLTheme.textPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updateWidgetData() {
        guard let latest = entries.first else { return }
        WidgetDataStore.update(lastWeight: latest.weight, unit: unit, streak: viewModel.calculateStreak(from: entries), entryDate: latest.date, goalWeight: settings?.goalWeight)
    }
}

struct StreakBadgeView: View { let streak: Int; var body: some View { EmptyView() } }
struct StatsRowView: View { let stats: WeightStats; let unit: WeightUnit; var body: some View { EmptyView() } }
