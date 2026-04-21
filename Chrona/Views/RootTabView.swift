import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ActiveSessionView()
                .tabItem {
                    Label(String(localized: "tab.active"), systemImage: "timer")
                }

            TaskListView()
                .tabItem {
                    Label(String(localized: "tab.tasks"), systemImage: "checklist")
                }

            StatisticsView()
                .tabItem {
                    Label(String(localized: "tab.statistics"), systemImage: "chart.xyaxis.line")
                }

            CountdownView()
                .tabItem {
                    Label(String(localized: "tab.countdown"), systemImage: "calendar")
                }

            ProfileView()
                .tabItem {
                    Label(String(localized: "tab.profile"), systemImage: "person.crop.circle")
                }
        }
    }
}
