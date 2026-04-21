import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section(String(localized: "about.app")) {
                Text("Chrona")
                Text(String(localized: "about.description"))
            }
            Section(String(localized: "about.contributors")) {
                Text(String(localized: "about.contributor.1"))
                Text(String(localized: "about.contributor.2"))
            }
            Section(String(localized: "about.localization")) {
                Text(String(localized: "about.localization.support"))
            }
        }
        .navigationTitle(String(localized: "profile.about"))
    }
}
