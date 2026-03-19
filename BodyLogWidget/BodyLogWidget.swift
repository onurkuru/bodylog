import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct BodyLogTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BodyLogEntry {
        BodyLogEntry(date: .now, weight: 72.4, unit: "kg", streak: 7, lastEntryDate: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (BodyLogEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BodyLogEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh at next midnight
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func currentEntry() -> BodyLogEntry {
        let defaults = UserDefaults(suiteName: "group.com.bodylog.app")
        let weight = defaults?.double(forKey: "lastWeight") ?? 0
        let unit = defaults?.string(forKey: "lastWeightUnit") ?? "kg"
        let streak = defaults?.integer(forKey: "currentStreak") ?? 0
        let lastInterval = defaults?.double(forKey: "lastEntryDate") ?? 0

        return BodyLogEntry(
            date: .now,
            weight: weight,
            unit: unit,
            streak: streak,
            lastEntryDate: lastInterval > 0 ? Date(timeIntervalSince1970: lastInterval) : nil
        )
    }
}

// MARK: - Widget Entry

struct BodyLogEntry: TimelineEntry {
    let date: Date
    let weight: Double
    let unit: String
    let streak: Int
    let lastEntryDate: Date?
}

// MARK: - Widget View

struct BodyLogWidgetView: View {
    var entry: BodyLogEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "scalemass.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("BodyLog")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            if entry.weight > 0 {
                // Weight
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", entry.weight))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(entry.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Streak
                if entry.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(entry.streak) day streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Last updated
                if let lastDate = entry.lastEntryDate {
                    Text(lastDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("Tap to log\nyour first weight")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "bodylog://dashboard/add-weight"))
    }
}

// MARK: - Widget Configuration

struct BodyLogWidget: Widget {
    let kind: String = "BodyLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BodyLogTimelineProvider()) { entry in
            BodyLogWidgetView(entry: entry)
        }
        .configurationDisplayName("BodyLog")
        .description("See your current weight and streak.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

@main
struct BodyLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BodyLogWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BodyLogWidget()
} timeline: {
    BodyLogEntry(date: .now, weight: 72.4, unit: "kg", streak: 14, lastEntryDate: .now)
    BodyLogEntry(date: .now, weight: 0, unit: "kg", streak: 0, lastEntryDate: nil)
}
