import SwiftUI
import UIKit
import MealieModel

struct RecipePDFFile: Identifiable {
    let url: URL
    var id: URL { url }

    @MainActor
    static func create(for recipe: Recipe, directory: URL = FileManager.default.temporaryDirectory) throws -> RecipePDFFile {
        let root = directory.appendingPathComponent("SharedRecipes", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // Keep recent exports alive while another app reads its attachment.
        for old in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
            if let created = try? old.resourceValues(forKeys: [.creationDateKey]).creationDate,
               created < Date().addingTimeInterval(-86400) { try? FileManager.default.removeItem(at: old) }
        }
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = String((recipe.name ?? "Recipe").unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" ? String($0) : "_"
        }.joined().prefix(60)).trimmingCharacters(in: .whitespaces)
        let url = folder.appendingPathComponent((name.isEmpty ? "Recipe" : name) + ".pdf")
        do {
            try RecipePDFRenderer.data(for: recipe).write(to: url, options: .atomic)
            return RecipePDFFile(url: url)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}

struct RecipeShareSheet: UIViewControllerRepresentable {
    let file: RecipePDFFile
    let onComplete: (String?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, error in
            onComplete(error == nil ? nil : "Could not share this recipe. Please try again.")
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
