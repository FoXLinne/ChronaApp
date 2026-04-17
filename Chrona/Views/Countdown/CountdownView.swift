import SwiftUI

struct CountdownView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var title = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "countdown.add")) {
                    TextField(String(localized: "countdown.name"), text: $title)
                    DatePicker(String(localized: "countdown.date"), selection: $date, displayedComponents: [.date])
                    Button(String(localized: "common.add")) {
                        appModel.addCountdownEvent(title: title, date: date)
                        title = ""
                        date = .now
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section(String(localized: "countdown.future")) {
                    ForEach(appModel.futureEvents) { event in
                        CountdownRow(event: event, future: true)
                    }
                    .onDelete { appModel.deleteCountdownEvents(at: $0, from: true) }
                }

                Section(String(localized: "countdown.past")) {
                    ForEach(appModel.pastEvents) { event in
                        CountdownRow(event: event, future: false)
                    }
                    .onDelete { appModel.deleteCountdownEvents(at: $0, from: false) }
                }
            }
            .navigationTitle(String(localized: "tab.countdown"))
        }
    }
}

private struct CountdownRow: View {
    let event: CountdownEvent
    let future: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(future ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .padding(.vertical, 4)
    }

    private var label: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: event.date)).day ?? 0
        if future {
            return String(format: String(localized: "countdown.inDays"), max(days, 0))
        }
        return String(format: String(localized: "countdown.pastDays"), abs(days))
    }
}

#Preview {
    CountdownView()
        .environmentObject(AppViewModel())
}
