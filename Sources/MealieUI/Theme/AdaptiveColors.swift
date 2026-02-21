import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif

public enum AdaptiveBackgroundStyle {
    case field
    case surface
    case sidebar
    case placeholder
}

public struct AdaptiveColors {
    public static func color(_ style: AdaptiveBackgroundStyle, isDark: Bool) -> Color {
        switch style {
        case .field:
            return Color(white: isDark ? 0.15 : 0.9)
        case .surface:
            return Color(white: isDark ? 0.18 : 0.9)
        case .sidebar:
            return Color(white: isDark ? 0.1 : 0.95)
        case .placeholder:
            return Color(white: isDark ? 0.2 : 0.85)
        }
    }
}
