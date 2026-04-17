import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            TaskListView()
                .tag(AppTab.tasks)
                .tabItem {
                    Label(String(localized: "tab.tasks"), systemImage: "checklist")
                }

            StatisticsView()
                .tag(AppTab.statistics)
                .tabItem {
                    Label(String(localized: "tab.statistics"), systemImage: "chart.xyaxis.line")
                }

            ActiveSessionView()
                .tag(AppTab.active)
                .tabItem {
                    Label(String(localized: "tab.active"), systemImage: "timer")
                }

            CountdownView()
                .tag(AppTab.countdown)
                .tabItem {
                    Label(String(localized: "tab.countdown"), systemImage: "calendar")
                }

            ProfileView()
                .tag(AppTab.profile)
                .tabItem {
                    Label(String(localized: "tab.profile"), systemImage: "person.crop.circle")
                }
        }
        .toolbar(appModel.selectedTab == .active && appModel.isActiveImmersiveChromeHidden ? .hidden : .visible, for: .tabBar)
        .onChange(of: appModel.selectedTab) { _, tab in
            if tab != .active && appModel.isActiveImmersiveChromeHidden {
                appModel.selectedTab = .active
                appModel.showGlobalNotice(String(localized: "session.immersive.locked"))
                return
            }
            if tab != .active {
                appModel.setActiveImmersiveChromeHidden(false)
            }
        }
        .overlay(alignment: .top) {
            if let message = appModel.globalNotice {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: appModel.globalNotice)
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppViewModel())
}
