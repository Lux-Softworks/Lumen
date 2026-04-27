import XCTest
@testable import Lumen

@MainActor
final class HapticsTests: XCTestCase {
    private var fired: [HapticsEvent] = []
    private var now: CFTimeInterval = 0

    override func setUp() async throws {
        Haptics.resetForTests()
        fired = []
        now = 0
        Haptics.clock = { [unowned self] in self.now }
        Haptics.fireImpl = { [unowned self] event in self.fired.append(event) }
    }

    override func tearDown() async throws {
        Haptics.resetForTests()
    }

    func test_offMode_dropsAllEvents() {
        Haptics.modeProvider = { .off }
        for event in [HapticsEvent.tap, .selection, .snap, .soft, .rigid, .success, .error] {
            Haptics.fire(event)
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func test_subtleMode_dropsTapAndSoftOnly() {
        Haptics.modeProvider = { .subtle }
        let events: [HapticsEvent] = [.tap, .selection, .snap, .soft, .rigid, .success, .error]
        for e in events {
            Haptics.fire(e)
            now += 1.0
        }
        XCTAssertEqual(fired, [.selection, .snap, .rigid, .success, .error])
    }

    func test_fullMode_firesEverything() {
        Haptics.modeProvider = { .full }
        let events: [HapticsEvent] = [.tap, .selection, .snap, .soft, .rigid, .success, .error]
        for e in events {
            Haptics.fire(e)
            now += 1.0
        }
        XCTAssertEqual(fired, events)
    }

    func test_throttle_dropsSecondTapWithinWindow() {
        Haptics.modeProvider = { .full }
        Haptics.fire(.tap)
        now += 0.02
        Haptics.fire(.tap)
        XCTAssertEqual(fired, [.tap])
    }

    func test_throttle_independentPerEventType() {
        Haptics.modeProvider = { .full }
        Haptics.fire(.tap)
        now += 0.01
        Haptics.fire(.selection)
        XCTAssertEqual(fired, [.tap, .selection])
    }

    func test_throttle_successBypasses() {
        Haptics.modeProvider = { .full }
        Haptics.fire(.success)
        now += 0.01
        Haptics.fire(.success)
        XCTAssertEqual(fired, [.success, .success])
    }

    func test_throttle_releasesAfterWindow() {
        Haptics.modeProvider = { .full }
        Haptics.fire(.tap)
        now += 0.10
        Haptics.fire(.tap)
        XCTAssertEqual(fired, [.tap, .tap])
    }
}
