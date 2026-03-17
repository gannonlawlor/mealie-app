#if canImport(UIKit)
import Foundation

private let logger = Log(category: "iCloudSync")

/// Simplified iCloud manager. With SwiftData + CloudKit, sync is handled
/// automatically by the framework. This class only checks availability.
public class ICloudSyncManager: @unchecked Sendable {
    public static let shared = ICloudSyncManager()

    private init() {}

    /// Check if iCloud is available on this device.
    public func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
}
#endif
