import Foundation
import SkipFuse

private let logger = Log(category: "RecipeSync")

public class RecipeSyncService: @unchecked Sendable {
    public static let shared = RecipeSyncService()

    private let directoryName = "mealie_recipe_sync"
    private let summaryIndexFile = "recipe_summaries.json"
    private let idsKey = "mealie_sync_recipe_ids"
    private let lastSyncKey = "mealie_sync_last_date"
    private let dateIndexKey = "mealie_sync_date_index"
    private let batchSize = 5

    private init() {}

    // MARK: - Observable State

    public var isSyncing: Bool = false
    public var syncedRecipeCount: Int {
        syncedIds().count
    }

    public var isSynced: Bool {
        UserDefaults.standard.object(forKey: lastSyncKey) != nil
    }

    public var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    // MARK: - Sync

    public func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        logger.info("Starting recipe sync...")

        do {
            // 1. Fetch all recipe summaries from server
            var allSummaries: [RecipeSummary] = []
            var page = 1
            var totalPages = 1

            while page <= totalPages {
                let response = try await MealieAPI.shared.getRecipes(page: page, perPage: 50)
                allSummaries.append(contentsOf: response.items)
                totalPages = response.totalPages
                page += 1
            }

            logger.info("Fetched \(allSummaries.count) recipe summaries from server")

            // 2. Determine which recipes need fetching
            let serverIds = Set(allSummaries.compactMap { $0.id })
            let localIds = syncedIds()
            let localDates = loadDateIndex()

            var slugsToFetch: [(id: String, slug: String)] = []
            for summary in allSummaries {
                guard let id = summary.id, let slug = summary.slug else { continue }
                if let localDate = localDates[id], localDate == (summary.dateUpdated ?? "") {
                    continue // already up to date
                }
                slugsToFetch.append((id: id, slug: slug))
            }

            logger.info("\(slugsToFetch.count) recipes need updating")

            // 3. Batch-fetch full details
            var updatedDates = localDates
            for batchStart in stride(from: 0, to: slugsToFetch.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, slugsToFetch.count)
                let batch = Array(slugsToFetch[batchStart..<batchEnd])

                await withTaskGroup(of: (String, Recipe?).self) { group in
                    for item in batch {
                        group.addTask {
                            do {
                                let recipe = try await MealieAPI.shared.getRecipe(slug: item.slug)
                                return (item.id, recipe)
                            } catch {
                                logger.error("Failed to fetch recipe \(item.slug): \(error)")
                                return (item.id, nil)
                            }
                        }
                    }

                    for await (id, recipe) in group {
                        if let recipe = recipe {
                            saveRecipe(recipe)
                            updatedDates[id] = recipe.dateUpdated ?? recipe.updatedAt ?? ""
                        }
                    }
                }
            }

            // 4. Remove recipes deleted from server
            let deletedIds = localIds.subtracting(serverIds)
            for id in deletedIds {
                removeRecipeFile(id: id)
                updatedDates.removeValue(forKey: id)
            }
            if !deletedIds.isEmpty {
                logger.info("Removed \(deletedIds.count) deleted recipes")
            }

            // 5. Update tracking and summary index
            saveSyncedIds(serverIds)
            saveDateIndex(updatedDates)
            saveSummaryIndex(allSummaries)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)

            logger.info("Sync complete: \(serverIds.count) recipes synced")
        } catch {
            logger.error("Recipe sync failed: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Read (Summary Index)

    public func loadSummaryIndex() -> [RecipeSummary] {
        guard let dir = storeDirectory() else { return [] }
        let fileURL = dir.appendingPathComponent(summaryIndexFile)
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([RecipeSummary].self, from: data)) ?? []
    }

    // MARK: - Read (Full Recipes)

    public func loadAllSyncedRecipes() -> [Recipe] {
        guard let dir = storeDirectory() else { return [] }
        var recipes: [Recipe] = []
        for id in syncedIds() {
            let fileURL = dir.appendingPathComponent("recipe_\(id).json")
            if let data = try? Data(contentsOf: fileURL),
               let recipe = try? JSONDecoder().decode(Recipe.self, from: data) {
                recipes.append(recipe)
            }
        }
        return recipes
    }

    public func loadRecipe(id: String) -> Recipe? {
        guard let dir = storeDirectory() else { return nil }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Recipe.self, from: data)
    }

    public func loadRecipeBySlug(slug: String) -> Recipe? {
        // Look up ID from summary index, then load by ID
        let summaries = loadSummaryIndex()
        guard let match = summaries.first(where: { $0.slug == slug }),
              let id = match.id else { return nil }
        return loadRecipe(id: id)
    }

    // MARK: - Targeted Updates (after writes)

    public func updateRecipe(_ recipe: Recipe) {
        saveRecipe(recipe)

        // Update summary index
        var summaries = loadSummaryIndex()
        let summary = RecipeSummary(
            id: recipe.id, slug: recipe.slug, name: recipe.name,
            description: recipe.description, image: recipe.image,
            recipeCategory: recipe.recipeCategory, tags: recipe.tags,
            rating: recipe.rating, dateAdded: recipe.dateAdded,
            dateUpdated: recipe.dateUpdated
        )
        if let idx = summaries.firstIndex(where: { $0.id == recipe.id }) {
            summaries[idx] = summary
        } else {
            summaries.insert(summary, at: 0)
            if let id = recipe.id {
                var ids = syncedIds()
                ids.insert(id)
                saveSyncedIds(ids)
            }
        }
        saveSummaryIndex(summaries)

        // Update date index
        if let id = recipe.id {
            var dates = loadDateIndex()
            dates[id] = recipe.dateUpdated ?? recipe.updatedAt ?? ""
            saveDateIndex(dates)
        }
    }

    public func removeRecipe(slug: String) {
        var summaries = loadSummaryIndex()
        guard let match = summaries.first(where: { $0.slug == slug }),
              let id = match.id else { return }

        removeRecipeFile(id: id)
        summaries.removeAll { $0.id == id }
        saveSummaryIndex(summaries)

        var ids = syncedIds()
        ids.remove(id)
        saveSyncedIds(ids)

        var dates = loadDateIndex()
        dates.removeValue(forKey: id)
        saveDateIndex(dates)
    }

    // MARK: - Clear

    public func clearAll() {
        guard let dir = storeDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
        UserDefaults.standard.removeObject(forKey: idsKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: dateIndexKey)
        isSyncing = false
    }

    // MARK: - Private Storage

    private func saveRecipe(_ recipe: Recipe) {
        guard let dir = storeDirectory(), let id = recipe.id else { return }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        do {
            let data = try JSONEncoder().encode(recipe)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save synced recipe \(id): \(error)")
        }
    }

    private func removeRecipeFile(id: String) {
        guard let dir = storeDirectory() else { return }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func saveSummaryIndex(_ summaries: [RecipeSummary]) {
        guard let dir = storeDirectory() else { return }
        let fileURL = dir.appendingPathComponent(summaryIndexFile)
        do {
            let data = try JSONEncoder().encode(summaries)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save summary index: \(error)")
        }
    }

    private func storeDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - ID Tracking

    private func syncedIds() -> Set<String> {
        let array = (UserDefaults.standard.object(forKey: idsKey) as? [String]) ?? []
        return Set(array)
    }

    private func saveSyncedIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: idsKey)
    }

    // MARK: - Date Index (for incremental sync)

    private func loadDateIndex() -> [String: String] {
        (UserDefaults.standard.object(forKey: dateIndexKey) as? [String: String]) ?? [:]
    }

    private func saveDateIndex(_ index: [String: String]) {
        UserDefaults.standard.set(index, forKey: dateIndexKey)
    }
}
