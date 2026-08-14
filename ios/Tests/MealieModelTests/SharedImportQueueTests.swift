import XCTest
import Foundation
@testable import MealieModel

/// The hand-off between the Share Extension and the app.
final class SharedImportQueueTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var queue: SharedImportQueue!

    override func setUp() {
        super.setUp()
        suiteName = "SharedImportQueueTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        queue = SharedImportQueue(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        queue = nil
        super.tearDown()
    }

    func testEnqueuePreservesOrder() {
        queue.enqueue("https://a.example.com/recipe")
        queue.enqueue("https://b.example.com/recipe")

        XCTAssertEqual(queue.pendingURLs(), [
            "https://a.example.com/recipe",
            "https://b.example.com/recipe",
        ])
    }

    func testEnqueueIgnoresDuplicatesAndEmpty() {
        queue.enqueue("https://a.example.com/recipe")
        queue.enqueue("https://a.example.com/recipe")
        queue.enqueue("")

        XCTAssertEqual(queue.pendingURLs(), ["https://a.example.com/recipe"])
    }

    func testRemoveLeavesTheRest() {
        queue.enqueue("https://a.example.com/recipe")
        queue.enqueue("https://b.example.com/recipe")

        queue.remove("https://a.example.com/recipe")

        XCTAssertEqual(queue.pendingURLs(), ["https://b.example.com/recipe"])
    }

    /// A link left behind by the pre-queue single-URL key must not be dropped.
    func testLegacySingleURLIsPickedUpThenFoldedIntoTheQueue() {
        defaults.set("https://legacy.example.com/recipe", forKey: SharedImportQueue.legacyPendingKey)

        XCTAssertEqual(queue.pendingURLs(), ["https://legacy.example.com/recipe"])

        queue.enqueue("https://new.example.com/recipe")

        XCTAssertEqual(queue.pendingURLs(), [
            "https://legacy.example.com/recipe",
            "https://new.example.com/recipe",
        ])
        XCTAssertNil(defaults.string(forKey: SharedImportQueue.legacyPendingKey))
    }

    func testRemovingTheLegacyURLClearsIt() {
        defaults.set("https://legacy.example.com/recipe", forKey: SharedImportQueue.legacyPendingKey)

        queue.remove("https://legacy.example.com/recipe")

        XCTAssertEqual(queue.pendingURLs(), [])
        XCTAssertNil(defaults.string(forKey: SharedImportQueue.legacyPendingKey))
    }

    func testCompletedSlugsRoundTrip() {
        queue.appendCompleted(slug: "spaghetti-carbonara")
        queue.appendCompleted(slug: "spaghetti-carbonara")
        queue.appendCompleted(slug: "overnight-oats")
        queue.appendCompleted(slug: "")

        XCTAssertEqual(queue.completedSlugs(), ["spaghetti-carbonara", "overnight-oats"])

        queue.clearCompleted()

        XCTAssertEqual(queue.completedSlugs(), [])
    }
}
