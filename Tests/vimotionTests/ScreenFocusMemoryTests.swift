import XCTest
import CoreGraphics
@testable import vimotion

/// Tests for the per-display focus memory used when jumping between displays.
final class ScreenFocusMemoryTests: XCTestCase {

    private func win(_ id: CGWindowID) -> WindowInfo {
        WindowInfo(id: id, pid: 0, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testEmptyMemoryHasNoWindow() {
        let memory = ScreenFocusMemory()

        XCTAssertNil(memory.lastWindow(on: 1))
    }

    func testRecordsOneWindowPerDisplay() {
        let memory = ScreenFocusMemory()

        memory.record(win(10), on: 1)
        memory.record(win(20), on: 2)

        XCTAssertEqual(memory.lastWindow(on: 1)?.id, 10)
        XCTAssertEqual(memory.lastWindow(on: 2)?.id, 20)
    }

    func testLatestRecordOverwritesPrevious() {
        let memory = ScreenFocusMemory()

        memory.record(win(10), on: 1)
        memory.record(win(11), on: 1)

        XCTAssertEqual(memory.lastWindow(on: 1)?.id, 11)
    }

    func testForgetDisplay() {
        let memory = ScreenFocusMemory()
        memory.record(win(10), on: 1)
        memory.record(win(20), on: 2)

        memory.forget(displayID: 1)

        XCTAssertNil(memory.lastWindow(on: 1))
        XCTAssertEqual(memory.lastWindow(on: 2)?.id, 20)
    }

    func testPruneDropsDisconnectedDisplays() {
        let memory = ScreenFocusMemory()
        memory.record(win(10), on: 1)
        memory.record(win(20), on: 2)

        memory.prune(keeping: [1])

        XCTAssertEqual(memory.lastWindow(on: 1)?.id, 10)
        XCTAssertNil(memory.lastWindow(on: 2))
    }
}
