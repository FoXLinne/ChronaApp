import SwiftUI

struct AppBackground: View {
    let seed: String

    private var palette: [Color] {
        switch seed {
        case "forest":
            return [Color(red: 0.12, green: 0.27, blue: 0.21), Color(red: 0.49, green: 0.70, blue: 0.53)]
        case "ocean":
            return [Color(red: 0.05, green: 0.22, blue: 0.43), Color(red: 0.27, green: 0.67, blue: 0.82)]
        case "lavender":
            return [Color(red: 0.33, green: 0.25, blue: 0.50), Color(red: 0.74, green: 0.63, blue: 0.89)]
        case "midnight":
            return [Color(red: 0.04, green: 0.07, blue: 0.13), Color(red: 0.14, green: 0.24, blue: 0.44)]
        case "mint":
            return [Color(red: 0.05, green: 0.32, blue: 0.30), Color(red: 0.42, green: 0.88, blue: 0.78)]
        default:
            return [Color(red: 0.95, green: 0.46, blue: 0.34), Color(red: 0.98, green: 0.84, blue: 0.55)]
        }
    }

    var body: some View {
        LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(.ultraThinMaterial.opacity(0.15))
            .ignoresSafeArea()
    }
}
