import Foundation
#if os(macOS)
import SkipTest

@available(macOS 13, macCatalyst 16, *)
final class XCSkipTests: XCTestCase, XCGradleHarness {
    public func testSkipModule() async throws {
        try await runGradleTests()
    }
}
#endif

let isJava = ProcessInfo.processInfo.environment["java.io.tmpdir"] != nil
let isAndroid = isJava && ProcessInfo.processInfo.environment["ANDROID_ROOT"] != nil
let isRobolectric = isJava && !isAndroid
