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
    private let keepAwakeKey = "mealie_keep_screen_awake"

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

    public var keepScreenAwake: Bool {
        get { UserDefaults.standard.bool(forKey: keepAwakeKey) }
        set { UserDefaults.standard.set(newValue, forKey: keepAwakeKey) }
    }
}
