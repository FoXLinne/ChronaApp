import SwiftUI

struct AppBackground: View {
    let seed: String

    private var palette: [Color] {
        switch seed {
        case "forest":
            return [Color(red: 0.12, green: 0.27, blue: 0.21), Color(red: 0.49, green: 0.70, blue: 0.53)]
        case "ocean":
            return [Color(red: 0.05, green: 0.22, blue: 0.43), Color(red: 0.27, green: 0.67, blue: 0.82)]
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
