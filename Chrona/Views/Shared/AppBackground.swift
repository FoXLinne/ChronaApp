import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let seed: String

    private var palette: [Color] {
        ThemePalette.activeBackgroundColors(for: seed, colorScheme: colorScheme)
    }

    var body: some View {
        LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(colorScheme == .dark ? 0.24 : 0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Color.black.opacity(colorScheme == .dark ? 0.14 : 0.03)
                    .blendMode(.multiply)
            )
            .overlay(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.08 : 0.15))
            .ignoresSafeArea()
    }
}
