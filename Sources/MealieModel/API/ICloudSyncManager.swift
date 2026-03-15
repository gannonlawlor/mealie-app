#if canImport(UIKit)
import Foundation

private let logger = Log(category: "iCloudSync")

public class ICloudSyncManager: @unchecked Sendable {
    public static let shared = ICloudSyncManager()

    private let containerID = "iCloud.com.jackabee.mealie"
    private var metadataQuery: NSMetadataQuery?
    private var onChange: (() -> Void)?

    private init() {}

    // MARK: - Availability

    public func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    public func iCloudContainerURL() -> URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: containerID)
    }

    // MARK: - Enable / Disable

    public func enableICloudSync() {
        guard let containerURL = iCloudContainerURL() else {
            logger.error("iCloud container not available")
            return
        }

        let recipesDir = containerURL.appendingPathComponent("Documents/Recipes")
        let fm = FileManager.default
        try? fm.createDirectory(at: recipesDir, withIntermediateDirectories: true)

        // Copy local recipes to iCloud if iCloud directory is empty
        let store = LocalRecipeStore.shared
        let iCloudFiles = (try? fm.contentsOfDirectory(at: recipesDir, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("recipe_") && $0.pathExtension == "json" } ?? []

        if iCloudFiles.isEmpty {
            logger.info("iCloud directory empty, copying local recipes to iCloud")
            store.copyAllFiles(to: recipesDir)
        }

        // Point the store at the iCloud directory
        store.setRootDirectory(recipesDir)
        logger.info("iCloud sync enabled, store directory: \(recipesDir.path)")
    }

    public func disableICloudSync() {
        let store = LocalRecipeStore.shared

        // Copy current recipes back to local before switching
        guard let localDir = store.rootDirectory() else { return }
        let defaultDir = defaultLocalDirectory()
        guard let defaultDir = defaultDir else { return }

        if localDir != defaultDir {
            logger.info("Copying recipes from iCloud to local storage")
            let fm = FileManager.default
            try? fm.createDirectory(at: defaultDir, withIntermediateDirectories: true)
            store.copyAllFiles(to: defaultDir)
        }

        // Reset to local storage
        store.setRootDirectory(nil)
        stopMonitoring()
        logger.info("iCloud sync disabled, reverted to local storage")
    }

    // MARK: - Monitoring

    public func startMonitoring(onChange: @escaping () -> Void) {
        self.onChange = onChange
        stopMonitoring()

        guard let containerURL = iCloudContainerURL() else { return }
        let recipesDir = containerURL.appendingPathComponent("Documents/Recipes")

        let query = NSMetadataQuery()
        query.searchScopes = [recipesDir]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        metadataQuery = query
        query.start()
        logger.info("Started iCloud file monitoring")
    }

    public func stopMonitoring() {
        metadataQuery?.stop()
        if let query = metadataQuery {
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        }
        metadataQuery = nil
        onChange = nil
    }

    // MARK: - Private

    @objc private func metadataQueryDidFinishGathering() {
        logger.info("iCloud initial gather complete")
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }

    @objc private func metadataQueryDidUpdate() {
        logger.info("iCloud files changed remotely")
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }

    private func defaultLocalDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("mealie_local")
    }
}
#endif
