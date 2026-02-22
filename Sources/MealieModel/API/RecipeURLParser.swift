import Foundation
import SkipFuse

private let logger = Log(category: "URLParser")

public enum RecipeParseError: Error {
    case invalidURL
    case fetchFailed(String)
    case noRecipeFound
    case parsingFailed(String)
}

public class RecipeURLParser: @unchecked Sendable {
    public static let shared = RecipeURLParser()

    private init() {}

    /// Parses recipe from raw HTML string. Exposed for testing.
    public func parseRecipeFromHTML(_ html: String, sourceURL: String) throws -> Recipe {
        let jsonBlocks = extractJSONLD(from: html)
        if jsonBlocks.isEmpty {
            throw RecipeParseError.noRecipeFound
        }
        for block in jsonBlocks {
            if let recipe = try findRecipe(in: block, sourceURL: sourceURL) {
                return recipe
            }
        }
        throw RecipeParseError.noRecipeFound
    }

    /// Fetches a URL, extracts JSON-LD, and returns a Recipe with a locally-saved image
    public func parseRecipe(from urlString: String) async throws -> Recipe {
        guard let url = URL(string: urlString) else {
            throw RecipeParseError.invalidURL
        }

        // Fetch HTML
        let html: String
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                logger.info("Fetch \(urlString) -> HTTP \(httpResponse.statusCode), \(data.count) bytes")
            }
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                throw RecipeParseError.fetchFailed("Could not decode HTML")
            }
            html = text
        } catch let error as RecipeParseError {
            throw error
        } catch {
            throw RecipeParseError.fetchFailed(error.localizedDescription)
        }

        // Extract JSON-LD blocks
        let jsonBlocks = extractJSONLD(from: html)
        logger.info("Found \(jsonBlocks.count) JSON-LD blocks in \(urlString)")

        if jsonBlocks.isEmpty {
            throw RecipeParseError.noRecipeFound
        }

        // Find recipe object in JSON-LD
        for block in jsonBlocks {
            do {
                if let recipe = try findRecipe(in: block, sourceURL: urlString) {
                    return recipe
                }
            } catch {
                logger.error("Error mapping recipe from JSON-LD: \(error)")
            }
        }

        logger.error("JSON-LD blocks found but none contained a Recipe type")
        throw RecipeParseError.noRecipeFound
    }

    // MARK: - JSON-LD Extraction

    private func extractJSONLD(from html: String) -> [Any] {
        var results: [Any] = []
        let marker = "application/ld+json"
        let endTag = "</script>"

        var searchRange = html.startIndex..<html.endIndex
        while let markerRange = html.range(of: marker, options: .caseInsensitive, range: searchRange) {
            // Find the closing > of this script tag
            guard let tagClose = html.range(of: ">", range: markerRange.upperBound..<html.endIndex) else {
                break
            }
            let contentStart = tagClose.upperBound
            guard let endRange = html.range(of: endTag, options: .caseInsensitive, range: contentStart..<html.endIndex) else {
                break
            }
            let jsonString = String(html[contentStart..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                results.append(json)
            } else {
                logger.info("Failed to parse JSON-LD block (\(jsonString.prefix(100))...)")
            }
            searchRange = endRange.upperBound..<html.endIndex
        }
        return results
    }

    // MARK: - Recipe Finding

    private func findRecipe(in json: Any, sourceURL: String) throws -> Recipe? {
        if let dict = json as? [String: Any] {
            // Check if this dict is a Recipe
            if isRecipeType(dict) {
                return try mapToRecipe(dict, sourceURL: sourceURL)
            }
            // If it has @graph, search inside
            if let graph = dict["@graph"] as? [Any] {
                for item in graph {
                    if let recipe = try findRecipe(in: item, sourceURL: sourceURL) {
                        return recipe
                    }
                }
            }
        }

        // If it's an array, search each item
        if let array = json as? [Any] {
            for item in array {
                if let recipe = try findRecipe(in: item, sourceURL: sourceURL) {
                    return recipe
                }
            }
        }

        return nil
    }

    private func isRecipeType(_ dict: [String: Any]) -> Bool {
        if let type = dict["@type"] as? String {
            return type == "Recipe"
        }
        if let types = dict["@type"] as? [String] {
            return types.contains("Recipe")
        }
        return false
    }

    // MARK: - Mapping

    private func mapToRecipe(_ dict: [String: Any], sourceURL: String) throws -> Recipe {
        let recipeId = UUID().uuidString
        let name = dict["name"] as? String ?? "Untitled"
        let slug = LocalRecipeStore.shared.generateSlug(from: name)
        let description = dict["description"] as? String

        // Image URL
        let imageURL = extractImageURL(from: dict["image"])

        // Download and save image locally
        var imagePath: String? = nil
        if let imgURLString = imageURL, let imgURL = URL(string: imgURLString) {
            if let imgData = try? Data(contentsOf: imgURL) {
                let path = LocalRecipeStore.shared.saveImage(data: imgData, recipeId: recipeId)
                if !path.isEmpty { imagePath = path }
            }
        }

        // Ingredients
        let ingredients: [RecipeIngredient]? = (dict["recipeIngredient"] as? [String])?.map { text in
            RecipeIngredient(
                quantity: nil, unit: nil, food: nil,
                note: text, isFood: false, disableAmount: true,
                display: text, title: nil, originalText: text, referenceId: UUID().uuidString
            )
        }

        // Instructions
        let instructions = extractInstructions(from: dict["recipeInstructions"])

        // Times
        let prepTime = dict["prepTime"] as? String
        let cookTime = dict["cookTime"] as? String
        let totalTime = dict["totalTime"] as? String

        // Yield
        let recipeYield = extractYield(from: dict["recipeYield"])

        // Nutrition
        let nutrition = extractNutrition(from: dict["nutrition"])

        // Categories
        let categories: [RecipeCategory]? = extractStringArray(from: dict["recipeCategory"])?.map { name in
            RecipeCategory(id: UUID().uuidString, name: name, slug: LocalRecipeStore.shared.generateSlug(from: name))
        }

        // Tags/keywords
        let tags: [RecipeTag]? = extractKeywords(from: dict["keywords"])?.map { name in
            RecipeTag(id: UUID().uuidString, name: name, slug: LocalRecipeStore.shared.generateSlug(from: name))
        }

        let now = ISO8601DateFormatter().string(from: Date())

        return Recipe(
            id: recipeId,
            slug: slug,
            name: name,
            description: description,
            image: imagePath,
            recipeCategory: categories,
            tags: tags,
            tools: nil,
            rating: nil,
            recipeYield: recipeYield,
            recipeIngredient: ingredients,
            recipeInstructions: instructions,
            totalTime: totalTime,
            prepTime: prepTime,
            performTime: cookTime,
            nutrition: nutrition,
            settings: nil,
            dateAdded: now,
            dateUpdated: now,
            createdAt: now,
            updatedAt: now,
            orgURL: sourceURL,
            extras: nil
        )
    }

    // MARK: - Field Extractors

    private func extractImageURL(from value: Any?) -> String? {
        if let str = value as? String { return str }
        if let dict = value as? [String: Any] { return dict["url"] as? String }
        if let arr = value as? [Any] {
            if let first = arr.first as? String { return first }
            if let first = arr.first as? [String: Any] { return first["url"] as? String }
        }
        return nil
    }

    private func extractInstructions(from value: Any?) -> [RecipeInstruction]? {
        guard let value = value else { return nil }

        // Array of strings
        if let strings = value as? [String] {
            return strings.map { text in
                RecipeInstruction(id: UUID().uuidString, title: nil, text: text, ingredientReferences: nil)
            }
        }

        // Array of HowToStep objects
        if let dicts = value as? [[String: Any]] {
            return dicts.compactMap { dict in
                // Handle HowToSection with itemListElement
                if let sectionName = dict["name"] as? String,
                   let items = dict["itemListElement"] as? [[String: Any]] {
                    // Flatten section steps
                    let steps = items.compactMap { item -> RecipeInstruction? in
                        let text = item["text"] as? String
                        return text != nil ? RecipeInstruction(id: UUID().uuidString, title: sectionName, text: text, ingredientReferences: nil) : nil
                    }
                    return steps.first // Simplification: return first step with section title
                }
                let text = dict["text"] as? String
                guard let text = text else { return nil }
                return RecipeInstruction(id: UUID().uuidString, title: nil, text: text, ingredientReferences: nil)
            }
        }

        return nil
    }

    private func extractYield(from value: Any?) -> String? {
        if let str = value as? String { return str }
        if let arr = value as? [String], let first = arr.first { return first }
        if let num = value as? Int { return "\(num)" }
        return nil
    }

    private func extractNutrition(from value: Any?) -> Nutrition? {
        guard let dict = value as? [String: Any] else { return nil }
        return Nutrition(
            calories: dict["calories"] as? String,
            fatContent: dict["fatContent"] as? String,
            proteinContent: dict["proteinContent"] as? String,
            carbohydrateContent: dict["carbohydrateContent"] as? String,
            fiberContent: dict["fiberContent"] as? String,
            sodiumContent: dict["sodiumContent"] as? String,
            sugarContent: dict["sugarContent"] as? String
        )
    }

    private func extractStringArray(from value: Any?) -> [String]? {
        if let arr = value as? [String], !arr.isEmpty { return arr }
        if let str = value as? String {
            let items = str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return items.isEmpty ? nil : items
        }
        return nil
    }

    private func extractKeywords(from value: Any?) -> [String]? {
        if let arr = value as? [String], !arr.isEmpty { return arr }
        if let str = value as? String {
            let items = str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return items.isEmpty ? nil : items
        }
        return nil
    }
}
