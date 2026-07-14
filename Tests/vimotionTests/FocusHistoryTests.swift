import XCTest
import CoreGraphics
@testable import vimotion

/// Tests for the pure focus-history logic backing the leader+n toggle, using
/// synthetic windows in the same style as `DirectionalNavigatorTests`.
final class FocusHistoryTests: XCTestCase {

    private func win(_ id: CGWindowID, _ x: CGFloat = 0, _ y: CGFloat = 0, _ w: CGFloat = 100, _ h: CGFloat = 100) -> WindowInfo {
        WindowInfo(id: id, pid: 0, frame: CGRect(x: x, y: y, width: w, height: h))
    }

    func testEmptyHistoryHasNoToggleTarget() {
        let history = FocusHistory()

        XCTAssertNil(history.toggleTarget(currentID: nil))
        XCTAssertNil(history.toggleTarget(currentID: 1))
    }

    func testRecordingTwoWindowsTracksCurrentAndPrevious() {
        let history = FocusHistory()
        let a = win(1)
        let b = win(2)

        history.record(a)
        history.record(b)

        XCTAssertEqual(history.current?.id, 2)
        XCTAssertEqual(history.previous?.id, 1)
    }

    func testDuplicateRecordRefreshesCurrentWithoutClobberingPrevious() {
        let history = FocusHistory()
        let a = win(1)
        let b = win(2)
        let movedB = win(2, 300, 300)

        history.record(a)
        history.record(b)
        history.record(movedB)

        XCTAssertEqual(history.current?.id, 2)
        XCTAssertEqual(history.current?.frame, movedB.frame)
        XCTAssertEqual(history.previous?.id, 1)
    }

    func testToggleTargetReturnsPrevious() {
        let history = FocusHistory()
        let a = win(1)
        let b = win(2)

        history.record(a)
        history.record(b)

        XCTAssertEqual(history.toggleTarget(currentID: b.id)?.id, 1)
    }

    func testTogglingTwiceReturnsToOriginal() {
        let history = FocusHistory()
        let a = win(1)
        let b = win(2)
        history.record(a)
        history.record(b)

        // First toggle lands on A; the coordinator records the new focus.
        let first = history.toggleTarget(currentID: b.id)
        history.record(first!)
        let second = history.toggleTarget(currentID: first?.id)

        XCTAssertEqual(first?.id, 1)
        XCTAssertEqual(second?.id, 2)
    }

    func testToggleTargetNeverReturnsCurrent() {
        let history = FocusHistory()
        let a = win(1)

        history.record(a)

        XCTAssertNil(history.toggleTarget(currentID: a.id))
    }

    func testDropPreviousClearsTargetButKeepsCurrent() {
        let history = FocusHistory()
        let a = win(1)
        let b = win(2)
        history.record(a)
        history.record(b)

        history.dropPrevious()

        XCTAssertNil(history.toggleTarget(currentID: b.id))
        XCTAssertEqual(history.current?.id, 2)
    }
}
