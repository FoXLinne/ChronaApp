import SwiftUI

struct DailyCheckInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: appModel.hasCheckedInToday ? "checkmark.circle.fill" : "calendar.badge.plus")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(appModel.hasCheckedInToday ? .green : .accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "checkin.title"))
                                .font(.headline)
                            Text(
                                appModel.hasCheckedInToday
                                    ? String(localized: "checkin.today.done")
                                    : String(localized: "checkin.today.pending")
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        statChip(
                            title: String(localized: "checkin.streak"),
                            value: String(format: String(localized: "checkin.streak.days"), appModel.checkInStreak)
                        )

                        statChip(
                            title: String(localized: "checkin.total"),
                            value: String(format: String(localized: "checkin.total.days"), appModel.totalCheckInCount)
                        )
                    }

                    Button {
                        if appModel.checkInToday() {
                            appModel.showGlobalNotice(String(localized: "checkin.success"))
                        }
                    } label: {
                        if appModel.hasCheckedInToday {
                            HStack(spacing: 8) {
                                Text(String(localized: "checkin.action.done"))
                            }
                            .frame(width: 108, height: 32)
                        } else {
                            HStack(spacing: 8) {
                                Text(String(localized: "checkin.action"))
                            }
                            .frame(width: 108, height: 32)
                            .foregroundStyle(Color.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.glass(.regular.tint(.accentColor)))
                    .disabled(appModel.hasCheckedInToday)
                }
                .padding(.vertical, 4)
            }

            Section(String(localized: "checkin.history")) {
                if appModel.checkInDates.isEmpty {
                    Text(String(localized: "checkin.history.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appModel.checkInDates.prefix(30)), id: \.self) { date in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(relativeLabel(for: date))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "checkin.title"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
        .background {
            if colorScheme == .light {
                PageBackground(seed: "sunset")
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func relativeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "checkin.history.today")
        }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now)).day {
            return String(format: String(localized: "checkin.history.daysAgo"), max(days, 0))
        }
        return ""
    }
}

#Preview {
    NavigationStack {
        DailyCheckInView()
            .environmentObject(AppViewModel.previewModel())
    }
}
