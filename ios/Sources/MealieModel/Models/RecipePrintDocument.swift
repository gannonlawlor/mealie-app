import Foundation

/// A self-contained, escaped print document built from the currently displayed recipe.
public enum RecipePrintDocument {
    public static func originalRecipeURL(for recipe: Recipe) -> URL? {
        guard let raw = recipe.orgURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    public static func html(for recipe: Recipe) -> String {
        func escape(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
        }
        func paragraph(_ value: String?) -> String {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
            return "<p>\(escape(value))</p>"
        }
        func field(_ label: String, _ value: String?) -> String {
            guard let value, !value.isEmpty else { return "" }
            return "<p><strong>\(label):</strong> \(escape(value))</p>"
        }
        func duration(_ value: String?) -> String? {
            guard let value, value.hasPrefix("PT") else { return value }
            return value.dropFirst(2).replacingOccurrences(of: "H", with: "h ")
                .replacingOccurrences(of: "M", with: "m ").replacingOccurrences(of: "S", with: "s").trimmingCharacters(in: .whitespaces)
        }
        var body = "<h1>\(escape(recipe.name?.isEmpty == false ? recipe.name! : "Recipe"))</h1>"
        if let url = originalRecipeURL(for: recipe) {
            body += "<p class='source'><a href=\"\(escape(url.absoluteString))\">Original recipe: \(escape(url.host!))</a></p>"
        }
        body += paragraph(recipe.description)
        body += "<div class='metadata'>" + field("Yield", recipe.recipeYield)
        body += field("Prep", duration(recipe.prepTime)) + field("Cook", duration(recipe.performTime)) + field("Total", duration(recipe.totalTime))
        body += field("Categories", recipe.recipeCategory?.compactMap(\.name).joined(separator: ", "))
        body += field("Tags", recipe.tags?.compactMap(\.name).joined(separator: ", "))
        body += field("Tools", recipe.tools?.compactMap(\.name).joined(separator: ", "))
        body += "</div>"
        if let ingredients = recipe.recipeIngredient, !ingredients.isEmpty {
            body += "<h2>Ingredients</h2>"
            for ingredient in ingredients {
                if let title = ingredient.title, !title.isEmpty { body += "<h3>\(escape(title))</h3>" }
                if !ingredient.displayText.isEmpty { body += "<p class='ingredient'>\(escape(ingredient.displayText))</p>" }
            }
        }
        if let instructions = recipe.recipeInstructions, !instructions.isEmpty {
            body += "<h2>Instructions</h2>"
            var step = 0
            for instruction in instructions {
                if let title = instruction.title, !title.isEmpty { body += "<h3>\(escape(title))</h3>" }
                if let text = instruction.text, !text.isEmpty {
                    step += 1
                    body += "<p class='step'><strong>\(step).</strong> \(escape(text))</p>"
                }
            }
        }
        if let n = recipe.nutrition {
            let values = field("Calories", n.calories) + field("Fat", n.fatContent) + field("Protein", n.proteinContent)
                + field("Carbs", n.carbohydrateContent) + field("Fiber", n.fiberContent) + field("Sugar", n.sugarContent)
            if !values.isEmpty { body += "<h2>Nutrition</h2><div class='metadata'>\(values)</div>" }
        }
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>\(escape(recipe.name ?? "Recipe"))</title>
        <style>
        body { font: 11pt -apple-system, Helvetica, Arial, sans-serif; color: #111; line-height: 1.45; }
        h1 { font-size: 24pt; line-height: 1.15; margin: 0 0 14pt; }
        h2 { font-size: 15pt; margin: 20pt 0 8pt; page-break-after: avoid; }
        h3 { font-size: 12pt; margin: 12pt 0 5pt; page-break-after: avoid; }
        p { margin: 0 0 8pt; white-space: pre-wrap; overflow-wrap: anywhere; word-wrap: break-word; }
        .source a { color: #1565c0; text-decoration: underline; }
        .metadata p { margin-bottom: 3pt; } .ingredient { margin-bottom: 5pt; }
        </style></head><body>\(body)</body></html>
        """
    }
}
