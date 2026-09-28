import SwiftUI

/// 应用程序的底栏标签视图，用于切换不同的功能页面，包含五个主要功能页面
struct RootTabView: View {
    /// 注入的应用模型对象，用于管理应用状态
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        // 主标签视图，根据 appModel.selectedTab 的值选择当前显示的标签页
        TabView(selection: $appModel.selectedTab) {
            // 任务列表页面 - 显示所有待办任务
            TaskListView()
                .tag(AppTab.tasks)  // 标签标识符
                .tabItem {
                    Label(String(localized: "tab.tasks"), systemImage: "checklist")  // 标签项显示文本和图标
                }
            
            // 倒数日页面 - 显示各种倒数日信息
            CountdownView()
                .tag(AppTab.countdown)
                .tabItem {
                    Label(String(localized: "tab.countdown"), systemImage: "calendar")
                }

            // 专注页面 - 显示当前正在进行的专注会话
            NavigationStack {
                ActiveSessionView()
            }
            .tag(AppTab.active)
            .tabItem {
                Label(String(localized: "tab.active"), systemImage: "timer")
            }

            // 统计页面 - 显示用户的统计数据和图表
            StatisticsView()
                .tag(AppTab.statistics)
                .tabItem {
                    Label(String(localized: "tab.statistics"), systemImage: "chart.xyaxis.line")
                }

            // 个人页面 - 用户个人设置和资料
            ProfileView()
                .tag(AppTab.profile)
                .tabItem {
                    Label(String(localized: "tab.profile"), systemImage: "person.crop.circle")
                }
        }
        // 根据当前标签页和沉浸模式状态控制工具栏（标签栏）的可见性
        .toolbar(appModel.selectedTab == .active && appModel.isActiveImmersiveChromeHidden ? .hidden : .visible, for: .tabBar)
        
        // 在视图顶部添加一个覆盖层，用于显示全局通知消息
        .overlay(alignment: .top) {
            // 如果存在全局通知消息，则显示通知横幅
            if let message = appModel.globalNotice {
                Text(message)  // 显示通知消息文本
                    .font(.subheadline.weight(.semibold))  // 设置字体样式：小标题，半粗体
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)  // 设置水平内边距为14
                    .padding(.vertical, 10)    // 设置垂直内边距为10
                    .glassEffect(.regular.interactive()) // 使用液态玻璃效果，支持交互
                    .padding(.top, 8)  // 设置顶部外边距为8
                    // 设置过渡动画：从顶部移动进入/退出 + 透明度变化
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // 为全局通知消息的出现/消失添加平滑动画
        .animation(.smooth, value: appModel.globalNotice)
        // 视图首次出现时同步屏幕旋转状态
        // 处理应用冷启动或视图重建时，旋转权限可能未初始化的边缘情况
        .onAppear {
            // 仅当当前标签为专注页（.active）时才允许旋转，其余标签页强制锁定竖屏
            InterfaceOrientationController.setRotationEnabled(appModel.selectedTab == .active)
        }
        // 监听标签页切换事件，实时同步屏幕旋转权限
        // 确保用户离开专注页时立即锁回竖屏，进入专注页时解锁横屏
        .onChange(of: appModel.selectedTab) { _, newTab in
            // 只有专注计时页（.active）需要支持横屏以适配沉浸式计时界面
            InterfaceOrientationController.setRotationEnabled(newTab == .active)
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppViewModel())
}
