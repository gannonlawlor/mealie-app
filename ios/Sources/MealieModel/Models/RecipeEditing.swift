import Foundation

/// An editor row keeps its source object even when other rows are removed.
public struct IngredientDraft: Identifiable {
    public let id = UUID()
    public let original: RecipeIngredient?
    public var text: String

    public init(_ original: RecipeIngredient? = nil) {
        self.original = original
        text = original?.displayText ?? ""
    }

    public var value: RecipeIngredient? {
        if let original, text == original.displayText { return original }
        guard !text.isEmpty else { return nil }
        return RecipeIngredient(quantity: nil, unit: nil, food: nil, note: text,
            isFood: false, disableAmount: true, display: text, title: original?.title,
            originalText: text, referenceId: original?.referenceId)
    }
}

public struct InstructionDraft: Identifiable {
    public let id = UUID()
    public let original: RecipeInstruction?
    public var text: String

    public init(_ original: RecipeInstruction? = nil) {
        self.original = original
        text = original?.text ?? ""
    }

    public var value: RecipeInstruction? {
        if let original, text == (original.text ?? "") { return original }
        guard !text.isEmpty else { return nil }
        return RecipeInstruction(id: original?.id, title: original?.title, text: text,
            ingredientReferences: original?.ingredientReferences)
    }
}

/// Preserve associations the editor cannot present (for example after a failed options request).
public func editedAssociations<T: Identifiable>(original: [T], available: [T], selected: Set<String?>) -> [T] where T.ID == String? {
    let editableIDs = Set(available.compactMap(\.id))
    let originalIDs = Set(original.compactMap(\.id))
    return original.filter { item in
        guard let id = item.id else { return true }
        return !editableIDs.contains(id) || selected.contains(id)
    } + available.filter { item in
        guard let id = item.id else { return false }
        return selected.contains(id) && !originalIDs.contains(id)
    }
}
