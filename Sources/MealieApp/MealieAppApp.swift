import Foundation
import MealieUI
import OSLog
import SwiftUI

fileprivate let logger: Logger = Logger(subsystem: "io.mealie.app", category: "MealieApp")

let androidSDK = ProcessInfo.processInfo.environment["android.os.Build.VERSION.SDK_INT"].flatMap({ Int($0) })

public struct RootView: View {
    public init() {
    }

    public var body: some View {
        ContentView()
            .task {
                logger.log("Mealie App started on \(androidSDK != nil ? "Android" : "iOS")")
            }
    }
}

#if !SKIP
public protocol MealieAppApp: App {
}

public extension MealieAppApp {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
#endif
