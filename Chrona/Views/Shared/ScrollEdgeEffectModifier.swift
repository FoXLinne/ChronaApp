import SwiftUI

extension View {
    @ViewBuilder
    func chronaSoftScrollEdgeEffect(_ edges: Edge.Set = [.top, .bottom]) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: edges)
        } else {
            self
        }
    }
}
