import Foundation
import MealieUI
#if canImport(OSLog)
import OSLog
#endif
import SwiftUI

let androidSDK = ProcessInfo.processInfo.environment["android.os.Build.VERSION.SDK_INT"].flatMap({ Int($0) })

public struct RootView: View {
    public init() {
    }

    public var body: some View {
        ContentView()
            .task {
                print("Mealie App started on \(androidSDK != nil ? "Android" : "iOS")")
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
