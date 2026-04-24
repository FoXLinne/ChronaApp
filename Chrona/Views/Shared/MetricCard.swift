import SwiftUI

struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())

            Group {
                if let subtitle {
                    Text(subtitle)
                } else {
                    Text(String(localized: "common.placeholder"))
                        .hidden()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
