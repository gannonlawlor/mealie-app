import Foundation
import SkipFuse

public struct AppEnvironment {
    /// Returns true for debug builds and TestFlight (non-App Store) builds.
    /// Use this to gate developer-facing diagnostics.
    public static var showDebugInfo: Bool {
        #if DEBUG
        return true
        #elseif os(Android)
        return false
        #else
        // TestFlight receipts use "sandboxReceipt"
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    /// Formats an error into a human-readable detail string for debug banners.
    public static func errorDetail(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return "Invalid URL"
            case .unauthorized:
                return "Unauthorized (401)"
            case .serverError(let code, let body):
                let truncated = body.prefix(200)
                return "Server error \(code): \(truncated)"
            case .decodingError(let underlying):
                return "Decoding error: \(underlying.localizedDescription)"
            case .networkError(let underlying):
                return "Network error: \(underlying.localizedDescription)"
            case .noData:
                return "No data received"
            }
        }
        return "\(error)"
    }
}
