import SwiftUI

enum ThemePalette {
    static let seeds = ["sunset", "forest", "ocean", "lavender", "midnight", "mint"]

    static func activeBackgroundColors(for seed: String, colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            switch seed {
            case "forest":
                return [Color(red: 0.07, green: 0.16, blue: 0.12), Color(red: 0.24, green: 0.40, blue: 0.28)]
            case "ocean":
                return [Color(red: 0.04, green: 0.12, blue: 0.20), Color(red: 0.12, green: 0.32, blue: 0.48)]
            case "lavender":
                return [Color(red: 0.16, green: 0.12, blue: 0.25), Color(red: 0.39, green: 0.30, blue: 0.57)]
            case "midnight":
                return [Color(red: 0.03, green: 0.05, blue: 0.09), Color(red: 0.08, green: 0.12, blue: 0.19)]
            case "mint":
                return [Color(red: 0.04, green: 0.18, blue: 0.17), Color(red: 0.15, green: 0.48, blue: 0.44)]
            default:
                return [Color(red: 0.18, green: 0.10, blue: 0.08), Color(red: 0.38, green: 0.24, blue: 0.15)]
            }
        case .light:
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
        @unknown default:
            return activeBackgroundColors(for: seed, colorScheme: .dark)
        }
    }

    static func editorBackgroundColors(for seed: String, colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            switch seed {
            case "forest":
                return [Color(red: 0.16, green: 0.17, blue: 0.16), Color(red: 0.20, green: 0.22, blue: 0.21)]
            case "ocean":
                return [Color(red: 0.15, green: 0.16, blue: 0.18), Color(red: 0.19, green: 0.21, blue: 0.24)]
            case "lavender":
                return [Color(red: 0.16, green: 0.15, blue: 0.18), Color(red: 0.20, green: 0.19, blue: 0.23)]
            case "midnight":
                return [Color(red: 0.14, green: 0.15, blue: 0.18), Color(red: 0.18, green: 0.19, blue: 0.23)]
            case "mint":
                return [Color(red: 0.15, green: 0.17, blue: 0.17), Color(red: 0.19, green: 0.22, blue: 0.21)]
            default:
                return [Color(red: 0.18, green: 0.16, blue: 0.15), Color(red: 0.22, green: 0.20, blue: 0.18)]
            }
        case .light:
            switch seed {
            case "forest":
                return [Color(red: 0.80, green: 0.94, blue: 0.86), Color(red: 0.90, green: 0.97, blue: 0.93)]
            case "ocean":
                return [Color(red: 0.82, green: 0.92, blue: 0.99), Color(red: 0.91, green: 0.97, blue: 1.00)]
            case "lavender":
                return [Color(red: 0.90, green: 0.88, blue: 0.96), Color(red: 0.96, green: 0.94, blue: 0.98)]
            case "midnight":
                return [Color(red: 0.78, green: 0.84, blue: 0.95), Color(red: 0.88, green: 0.93, blue: 0.98)]
            case "mint":
                return [Color(red: 0.86, green: 0.96, blue: 0.92), Color(red: 0.94, green: 0.99, blue: 0.97)]
            default:
                return [Color(red: 0.98, green: 0.85, blue: 0.79), Color(red: 1.00, green: 0.93, blue: 0.86)]
            }
        @unknown default:
            return editorBackgroundColors(for: seed, colorScheme: .dark)
        }
    }

    static func previewColors(for seed: String) -> [Color] {
        switch seed {
        case "forest":
            return [Color.green, Color.mint]
        case "ocean":
            return [Color.blue, Color.cyan]
        case "lavender":
            return [Color.purple, Color.indigo]
        case "midnight":
            return [Color.black, Color.blue]
        case "mint":
            return [Color.teal, Color.mint]
        default:
            return [Color.orange, Color.pink]
        }
    }
}