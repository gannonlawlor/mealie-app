import Foundation
#if canImport(OSLog)
import OSLog
#endif

public struct Log: Sendable {
    let category: String

    public init(category: String) {
        self.category = category
    }

    public func info(_ message: String) {
        #if canImport(OSLog)
        Logger(subsystem: "com.jackabee.mealie", category: category).info("\(message)")
        #else
        print("[\(category)] \(message)")
        #endif
    }

    public func error(_ message: String) {
        #if canImport(OSLog)
        Logger(subsystem: "com.jackabee.mealie", category: category).error("\(message)")
        #else
        print("[\(category)] ERROR: \(message)")
        #endif
    }
}
