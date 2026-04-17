import SwiftUI
import UIKit

/// 关于应用页面，展示 App Icon、应用信息、贡献者和本地化语言支持
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appIconTileSize: CGFloat = 128

    /// 从应用包内读取主 App Icon
    /// 通过 CFBundleIcons 查询原始文件名，读取 @2x 版本的 PNG
    private var appIconImage: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconFile = iconFiles.first,
            let iconPath = Bundle.main.path(forResource: "\(iconFile)@2x", ofType: "png")
        else {
            return nil
        }

        return UIImage(contentsOfFile: iconPath)
    }

    /// 应用信息区域：Icon、应用名、简介文案
    private var heroSection: some View {
        VStack(spacing: 18) {
            // App Icon（加载失败时显示备选符号）
            Group {
                if let appIconImage {
                    Image(uiImage: appIconImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: appIconTileSize * 0.72, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: appIconTileSize, height: appIconTileSize)
            .clipShape(
                RoundedRectangle(cornerRadius: appIconTileSize * 0.2237, style: .continuous)
            )

            // 应用名称
            Text("Chrona")
                .font(.system(size: 42, weight: .semibold, design: .rounded))

            // 应用简介
            Text(String(localized: "about.description"))
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(.primary.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    var body: some View {
        List {
            // 应用信息：Icon、名称、简介
            Section {
                heroSection
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 贡献者信息
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)

                    Text("@星見カエデ")
                        .fontWeight(.semibold)

                    Spacer()

                    Text(String(localized: "about.contributor.role"))
                        .fontWeight(.semibold)
                }
            } header: {
                Text(String(localized: "about.contributors"))
            }

            // 支持的本地化语言列表
            Section {
                HStack {
                    Text(String(localized: "about.localization.builtin"))
                        .fontWeight(.semibold)
                    Spacer()
                    Text("English (US)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text(String(localized: "about.localization.builtin"))
                        .fontWeight(.semibold)
                    Spacer()
                    Text("中文（简体）")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text(String(localized: "about.localization.ai"))
                        .fontWeight(.semibold)
                    Spacer()
                    Text("中文（繁體）")
                        .fontWeight(.semibold)
                }
            } header: {
                Text(String(localized: "about.localization"))
            } footer: {
                Text(String(localized: "about.localization.support"))
                    .font(.footnote)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "profile.about"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
