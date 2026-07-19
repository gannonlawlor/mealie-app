import Foundation
import MealieUI
#if canImport(OSLog)
import OSLog
#endif
import SwiftUI

public struct RootView: View {
    public init() {
    }

    public var body: some View {
        ContentView()
            .task {
                #if canImport(OSLog)
                Logger(subsystem: "com.jackabee.mealie", category: "App").info("Mealie App started on iOS")
                #else
                print("[App] Mealie App started on iOS")
                #endif
            }
    }
}

public protocol MealieAppApp: App {
}

public extension MealieAppApp {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
