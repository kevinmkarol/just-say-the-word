// ABOUTME: The Activity section: what the app has done lately, newest first, read from its log. Each entry is a
// ABOUTME: headline with its time and detail beneath, grouped by day, with problems picked out in red.
import JustSayTheWordCore
import SwiftUI

struct ActivityView: View {
    let model: AppModel

    var body: some View {
        List {
            ForEach(Array(ActivityLog.byDay(model.activity).enumerated()), id: \.offset) { dayIndex, day in
                Section(Self.title(forDay: day.day)) {
                    // A row's identity has to be its own across the whole list, not only within its day.
                    ForEach(Array(day.entries.enumerated()), id: \.offset) { index, entry in
                        ActivityRow(entry: entry).id("\(dayIndex)-\(index)")
                    }
                }
            }
        }
        .overlay {
            if model.activity.isEmpty {
                ContentUnavailableView("Nothing logged yet", systemImage: "list.bullet.rectangle")
            }
        }
        .toolbar {
            Button("Show Log File", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([Log.url])
            }
            .help("Show the log file in Finder")
        }
        .navigationTitle("Activity")
    }

    private static let dayFormat: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd"
        return format
    }()

    /// "Today", "Yesterday" or the date in full for a log day ("yyyy-MM-dd"); the day as written when it is not one.
    private static func title(forDay day: String) -> String {
        guard let date = dayFormat.date(from: day) else { return day.isEmpty ? "No date" : day }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .complete, time: .omitted)
    }
}

private struct ActivityRow: View {
    let entry: ActivityEntry

    /// The time and the detail, whichever of them the entry has.
    private var caption: String {
        [entry.clock, entry.detail ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if entry.isProblem {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                } else {
                    Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 18, height: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.headline.prefix(1).uppercased() + entry.headline.dropFirst())
                    .foregroundStyle(entry.isProblem ? Color.red : Color.primary)
                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
