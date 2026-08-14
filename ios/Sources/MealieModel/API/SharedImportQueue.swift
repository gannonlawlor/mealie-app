import Foundation

/// The App Group container shared by the app and the Share Extension.
///
/// The extension target does not link MealieModel, so
/// `Darwin/ShareExtension/ShareViewController.swift` repeats these identifiers
/// and key names as literals — keep the two in sync.
public enum SharedAppGroup {
    public static let identifier = "group.com.jackabee.mealie"

    /// Nil only if the App Group entitlement is missing/misconfigured.
    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

/// Hand-off between the Share Extension and the app.
///
/// The extension imports a shared URL itself whenever it can reach the server.
/// Two things can still need the app:
///
/// - `pendingURLs`: links the extension could not import (local mode, no
///   session, server unreachable). The app drains these on activation.
/// - `completedSlugs`: recipes the extension *did* create on the server. The
///   app pulls each one into the sync store so the list shows it immediately
///   instead of waiting for the next full sync.
public struct SharedImportQueue {
    static let pendingKey = "pendingImportURLs"
    /// Single-URL key written by versions before the queue existed.
    static let legacyPendingKey = "pendingImportURL"
    static let completedKey = "completedImportSlugs"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The queue backed by the App Group, or nil if it is unavailable.
    public static var shared: SharedImportQueue? {
        SharedAppGroup.defaults.map { SharedImportQueue(defaults: $0) }
    }

    // MARK: - Pending imports

    /// Queued URLs in the order they were shared, including any left behind by
    /// the pre-queue single-URL key. Duplicates are collapsed.
    public func pendingURLs() -> [String] {
        var urls = defaults.stringArray(forKey: Self.pendingKey) ?? []
        if let legacy = defaults.string(forKey: Self.legacyPendingKey), !legacy.isEmpty {
            urls.append(legacy)
        }
        var seen = Set<String>()
        return urls.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public func enqueue(_ url: String) {
        guard !url.isEmpty else { return }
        var urls = pendingURLs()
        guard !urls.contains(url) else { return }
        urls.append(url)
        write(pending: urls)
    }

    public func remove(_ url: String) {
        write(pending: pendingURLs().filter { $0 != url })
    }

    private func write(pending urls: [String]) {
        defaults.set(urls, forKey: Self.pendingKey)
        // The legacy key is folded into the array, so it must not linger.
        defaults.removeObject(forKey: Self.legacyPendingKey)
    }

    // MARK: - Imports the extension already completed

    public func completedSlugs() -> [String] {
        defaults.stringArray(forKey: Self.completedKey)?.filter { !$0.isEmpty } ?? []
    }

    public func appendCompleted(slug: String) {
        guard !slug.isEmpty else { return }
        var slugs = completedSlugs()
        guard !slugs.contains(slug) else { return }
        slugs.append(slug)
        defaults.set(slugs, forKey: Self.completedKey)
    }

    public func clearCompleted() {
        defaults.removeObject(forKey: Self.completedKey)
    }
}
