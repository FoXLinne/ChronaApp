import SwiftUI

struct ListEmptyStateView<ActionLabel: View>: View {
    let searchText: String
    let title: String
    let message: String
    let action: (() -> Void)?
    @ViewBuilder let actionLabel: () -> ActionLabel

    init(
        searchText: String,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        @ViewBuilder actionLabel: @escaping () -> ActionLabel = { EmptyView() }
    ) {
        self.searchText = searchText
        self.title = title
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        Group {
            if searchText.isEmpty {
                regularEmptyState
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var regularEmptyState: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let action {
                Button(action: action) {
                    actionLabel()
                }
                .buttonStyle(.glass(.regular.tint(.accentColor)))
                .padding(.top, 4)
            }
        }
    }
}
