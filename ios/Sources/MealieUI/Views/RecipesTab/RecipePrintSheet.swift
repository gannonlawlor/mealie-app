import SwiftUI
import UIKit
import MealieModel

/// Builds a paginated PDF, then hands it to the native print preview (which also offers sharing).
@MainActor
enum RecipePDFRenderer {
    private final class Pages: UIPrintPageRenderer {
        override var paperRect: CGRect { CGRect(x: 0, y: 0, width: 612, height: 792) }
        override var printableRect: CGRect { paperRect.insetBy(dx: 36, dy: 36) }
    }

    static func data(for recipe: Recipe) -> Data {
        let pages = Pages()
        pages.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: RecipePrintDocument.html(for: recipe)), startingAtPageAt: 0)
        let count = pages.numberOfPages
        pages.prepare(forDrawingPages: NSRange(location: 0, length: count))
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: recipe.name ?? "Recipe"]
        return UIGraphicsPDFRenderer(bounds: pages.paperRect, format: format).pdfData { context in
            for page in 0..<count {
                context.beginPage()
                pages.drawPage(at: page, in: pages.paperRect)
            }
        }
    }
}

struct RecipePrintSheet: UIViewControllerRepresentable {
    let recipe: Recipe
    let onComplete: (String?) -> Void

    func makeUIViewController(context: Context) -> PrintController {
        PrintController(recipe: recipe, onComplete: onComplete)
    }
    func updateUIViewController(_ uiViewController: PrintController, context: Context) {}

    final class PrintController: UIViewController {
        private let recipe: Recipe
        private let onComplete: (String?) -> Void
        private var started = false

        init(recipe: Recipe, onComplete: @escaping (String?) -> Void) {
            self.recipe = recipe; self.onComplete = onComplete
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(spinner)
            NSLayoutConstraint.activate([spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
            spinner.startAnimating()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !started else { return }
            started = true
            let data = RecipePDFRenderer.data(for: recipe)
            guard UIPrintInteractionController.canPrint(data) else {
                onComplete("Could not prepare this recipe for printing. Please try again.")
                return
            }
            let printer = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = recipe.name ?? "Recipe"
            info.outputType = .general
            printer.printInfo = info
            printer.printingItem = data
            let finished: UIPrintInteractionController.CompletionHandler = { [onComplete] _, _, error in
                onComplete(error == nil ? nil : "Could not print this recipe. Please try again.")
            }
            let presented: Bool
            if traitCollection.userInterfaceIdiom == .pad {
                presented = printer.present(from: CGRect(x: view.bounds.midX, y: 32, width: 1, height: 1),
                    in: view, animated: true, completionHandler: finished)
            } else {
                presented = printer.present(animated: true, completionHandler: finished)
            }
            if !presented { onComplete("Printing is unavailable. Please try again.") }
        }
    }
}
