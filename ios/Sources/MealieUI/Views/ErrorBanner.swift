import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct ErrorBanner: View {
    let message: String
    var detail: String = ""
    var onDismiss: () -> Void
    @State var showDetail: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                if AppEnvironment.showDebugInfo && !detail.isEmpty {
                    Button(action: { showDetail.toggle() }) {
                        Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            if AppEnvironment.showDebugInfo && !detail.isEmpty && showDetail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.9))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
