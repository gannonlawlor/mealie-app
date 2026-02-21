import Foundation
import SkipFuse

public enum AppTheme: String, Sendable {
    case system
    case light
    case dark
}

public class AppSettings: @unchecked Sendable {
    public static let shared = AppSettings()

    private let themeKey = "mealie_app_theme"

    private init() {}

    public var theme: AppTheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: themeKey),
                  let value = AppTheme(rawValue: raw) else {
                return .system
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
        }
    }
}
