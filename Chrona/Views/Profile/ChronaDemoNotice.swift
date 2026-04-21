import SwiftUI

/// Chrona 演示版本声明组件
/// 当应用进入正式生产版本时，可以移除或注释掉此视图的引用
struct ChronaDemoNotice: View {
    var body: some View {
        Text(String(localized: "demo.version.notice"))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
