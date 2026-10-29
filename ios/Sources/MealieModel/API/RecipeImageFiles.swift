import Foundation
import CryptoKit

/// Disposable device-local copies of image bytes retained in the recipe database.
/// CloudKit syncs RecipeEntity.imageData, never a device's absolute file path.
enum RecipeImageFiles {
    static func isLocalPath(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.hasPrefix("/") || URL(string: value)?.isFileURL == true
    }

    static func readLocalImage(_ value: String?) -> Data? {
        guard let value, isLocalPath(value) else { return nil }
        let url = value.hasPrefix("/") ? URL(fileURLWithPath: value) : URL(string: value)!
        return try? Data(contentsOf: url)
    }

    static func url(recipeId: String) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = root.appendingPathComponent("mealie_local/images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = SHA256.hash(data: Data(recipeId.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(name).jpg")
    }

    static func write(_ data: Data, recipeId: String) throws -> String {
        let target = try url(recipeId: recipeId)
        // Avoid rewriting the file on every list/detail fetch.
        if (try? Data(contentsOf: target)) != data {
            try data.write(to: target, options: .atomic)
        }
        return target.path
    }
}
