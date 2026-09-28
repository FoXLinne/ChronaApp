import SwiftUI

struct PageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let seed: String

    private var palette: [Color] {
        ThemePalette.editorBackgroundColors(for: seed, colorScheme: colorScheme)
    }

    private var glowColor: Color {
        switch colorScheme {
        case .dark:
            return .white.opacity(0.015)
        default:
            return .white.opacity(0.15)
        }
    }

    private var baseBlendColor: Color {
        switch colorScheme {
        case .dark:
            return Color(uiColor: .systemGroupedBackground).opacity(0.82)
        default:
            return Color(uiColor: .systemGroupedBackground).opacity(0.43)
        }
    }

    var body: some View {
        LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(baseBlendColor)
            .overlay(
                RadialGradient(
                    colors: [glowColor, .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 420
                )
            )
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(colorScheme == .dark ? 0.03 : 0.004), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        .ignoresSafeArea()
    }
}