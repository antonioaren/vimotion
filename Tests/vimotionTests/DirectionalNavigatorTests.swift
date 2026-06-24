import XCTest
import CoreGraphics
@testable import vimotion

/// Tests for the pure directional navigation logic, using synthetic layouts in
/// the top-left coordinate convention (y grows downward).
final class DirectionalNavigatorTests: XCTestCase {

    private let nav = DirectionalNavigator()

    private func win(_ id: CGWindowID, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> WindowInfo {
        WindowInfo(id: id, pid: 0, frame: CGRect(x: x, y: y, width: w, height: h))
    }

    // MARK: - Direction mapping

    func testKeyMapping() {
        XCTAssertEqual(Direction(key: "h"), .left)
        XCTAssertEqual(Direction(key: "j"), .down)
        XCTAssertEqual(Direction(key: "k"), .up)
        XCTAssertEqual(Direction(key: "l"), .right)
        XCTAssertNil(Direction(key: "x"))
    }

    // MARK: - Side by side

    func testSideBySideHorizontal() {
        let a = win(1, 0, 0, 100, 100)
        let b = win(2, 200, 0, 100, 100)
        let all = [a, b]

        XCTAssertEqual(nav.nextWindow(from: a, direction: .right, candidates: all)?.id, 2)
        XCTAssertEqual(nav.nextWindow(from: b, direction: .left, candidates: all)?.id, 1)
        XCTAssertNil(nav.nextWindow(from: a, direction: .up, candidates: all))
        XCTAssertNil(nav.nextWindow(from: a, direction: .down, candidates: all))
    }

    // MARK: - Stacked vertically

    func testStackedVertical() {
        let a = win(1, 0, 0, 100, 100)
        let b = win(2, 0, 200, 100, 100)
        let all = [a, b]

        XCTAssertEqual(nav.nextWindow(from: a, direction: .down, candidates: all)?.id, 2)
        XCTAssertEqual(nav.nextWindow(from: b, direction: .up, candidates: all)?.id, 1)
        XCTAssertNil(nav.nextWindow(from: a, direction: .left, candidates: all))
        XCTAssertNil(nav.nextWindow(from: a, direction: .right, candidates: all))
    }

    // MARK: - 2x2 grid

    func testGridPicksAlignedNeighbour() {
        let tl = win(1, 0, 0, 100, 100)
        let tr = win(2, 200, 0, 100, 100)
        let bl = win(3, 0, 200, 100, 100)
        let br = win(4, 200, 200, 100, 100)
        let all = [tl, tr, bl, br]

        // From top-left, right should pick the aligned top-right, not bottom-right.
        XCTAssertEqual(nav.nextWindow(from: tl, direction: .right, candidates: all)?.id, 2)
        // Down should pick bottom-left.
        XCTAssertEqual(nav.nextWindow(from: tl, direction: .down, candidates: all)?.id, 3)
        // From bottom-left, up should pick aligned top-left.
        XCTAssertEqual(nav.nextWindow(from: bl, direction: .up, candidates: all)?.id, 1)
        // From bottom-right, left should pick bottom-left.
        XCTAssertEqual(nav.nextWindow(from: br, direction: .left, candidates: all)?.id, 3)
    }

    // MARK: - Alignment reward

    func testPrefersOverlappingAlignedWindow() {
        // Source spans full height on the left.
        let source = win(1, 0, 0, 100, 400)
        // A small top-right window and a full-height right window.
        let topRight = win(2, 200, 0, 100, 100)
        let fullRight = win(3, 200, 0, 100, 400)
        let all = [source, topRight, fullRight]

        // The full-height right window overlaps the source vertically and should
        // be preferred over the offset small one.
        XCTAssertEqual(nav.nextWindow(from: source, direction: .right, candidates: all)?.id, 3)
    }

    // MARK: - Edge cases

    func testNoCandidateReturnsNil() {
        let a = win(1, 0, 0, 100, 100)
        XCTAssertNil(nav.nextWindow(from: a, direction: .right, candidates: [a]))
    }

    func testSourceIsExcluded() {
        let a = win(1, 0, 0, 100, 100)
        let b = win(2, 200, 0, 100, 100)
        // Even if the source id also matches a far window, it is never returned.
        XCTAssertNotEqual(nav.nextWindow(from: a, direction: .right, candidates: [a, b])?.id, 1)
    }

    func testNearestIsChosenAmongMultiple() {
        let a = win(1, 0, 0, 100, 100)
        let near = win(2, 150, 0, 100, 100)
        let far = win(3, 500, 0, 100, 100)
        let all = [a, near, far]
        XCTAssertEqual(nav.nextWindow(from: a, direction: .right, candidates: all)?.id, 2)
    }

    func testLookupSourceByID() {
        let a = win(1, 0, 0, 100, 100)
        let b = win(2, 200, 0, 100, 100)
        XCTAssertEqual(nav.nextWindow(fromID: 1, direction: .right, candidates: [a, b])?.id, 2)
        XCTAssertNil(nav.nextWindow(fromID: 99, direction: .right, candidates: [a, b]))
    }
}
