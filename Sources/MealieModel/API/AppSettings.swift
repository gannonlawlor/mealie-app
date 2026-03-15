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
    private let addToRemindersKey = "mealie_add_to_reminders"
    private let localGroceryListKey = "mealie_local_grocery_list"
    private let defaultShoppingListIdKey = "mealie_default_shopping_list_id"
    private let defaultShoppingListNameKey = "mealie_default_shopping_list_name"
    private let iCloudSyncKey = "mealie_icloud_sync"

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

    public var addToReminders: Bool {
        get { UserDefaults.standard.bool(forKey: addToRemindersKey) }
        set { UserDefaults.standard.set(newValue, forKey: addToRemindersKey) }
    }

    public var localGroceryList: Bool {
        get { UserDefaults.standard.bool(forKey: localGroceryListKey) }
        set { UserDefaults.standard.set(newValue, forKey: localGroceryListKey) }
    }

    public var defaultShoppingListId: String? {
        get { UserDefaults.standard.string(forKey: defaultShoppingListIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultShoppingListIdKey) }
    }

    public var defaultShoppingListName: String? {
        get { UserDefaults.standard.string(forKey: defaultShoppingListNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultShoppingListNameKey) }
    }

    public var iCloudSync: Bool {
        get { UserDefaults.standard.bool(forKey: iCloudSyncKey) }
        set { UserDefaults.standard.set(newValue, forKey: iCloudSyncKey) }
    }
}
