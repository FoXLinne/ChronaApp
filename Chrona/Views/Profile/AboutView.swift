import SwiftUI

/// 关于应用页面，展示 App Icon、应用信息、贡献者和本地化语言支持
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let appIconTileSize: CGFloat = 128

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return version == build ? version : "\(version) (\(build))"
    }

    private var appVersionLine: String {
        "\(String(localized: "about.version")) \(appVersionText)"
    }

    private var aboutIconAssetName: String {
        colorScheme == .dark ? "aboutAppIconDark" : "aboutAppIconDefault"
    }

    /// 应用信息区域：Icon、应用名、简介文案
    private var heroSection: some View {
        VStack(spacing: 18) {
            Group {
                Image(aboutIconAssetName)
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: appIconTileSize, height: appIconTileSize)
            .clipShape(
                RoundedRectangle(cornerRadius: appIconTileSize * 0.2237, style: .continuous)
            )

            // 应用名称
            Text("Chrona")
                .font(.system(size: 48, weight: .semibold, design: .rounded))

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
                    Image("contributor1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())

                    Text("@星見カエデ")
                        .fontWeight(.semibold)

                    Spacer()

                    Text(String(localized: "about.contributor.role.1"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 14) {
                    Image("contributor2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())

                    Text("@Sen")
                        .fontWeight(.semibold)

                    Spacer()

                    Text(String(localized: "about.contributor.role.2"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

            } header: {
                Text(String(localized: "about.contributors"))
            }

            // 支持的本地化语言列表
            Section {
                HStack {
                    Text("中文（简体）")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(localized: "about.localization.builtin"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("English (US)")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(localized: "about.localization.ai"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("中文（繁體）")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(localized: "about.localization.ai"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("日本語")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(localized: "about.localization.ai"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "about.localization"))
            } footer: {
                Text(String(localized: "about.localization.support"))
                    .font(.footnote)
            }

            Section {
                HStack {
                    Spacer()
                    Text(appVersionLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // --- 演示版本声明（已注释，正式版移除）---
            // ---------------------------------------------------------
        }
        .listStyle(.insetGrouped)
        .chronaSoftScrollEdgeEffect()
        .navigationTitle(String(localized: "profile.about"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    dismiss()
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
