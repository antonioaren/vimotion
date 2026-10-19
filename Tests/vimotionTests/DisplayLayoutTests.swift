import XCTest
import CoreGraphics
@testable import vimotion

/// Tests for the pure display-arrangement logic, using synthetic layouts in the
/// top-left coordinate convention (the primary display sits at (0, 0), and a
/// display arranged above it has a negative `y`).
final class DisplayLayoutTests: XCTestCase {

    private let laptop = DisplayInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), isPrimary: true, name: "Built-in")

    private func display(_ id: CGDirectDisplayID, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, name: String = "External") -> DisplayInfo {
        DisplayInfo(id: id, frame: CGRect(x: x, y: y, width: w, height: h), name: name)
    }

    // MARK: - Single display

    func testSingleDisplayHasNoNeighbors() {
        let layout = DisplayLayout(displays: [laptop])

        for direction in Direction.allCases {
            XCTAssertNil(layout.neighbor(of: laptop, direction: direction))
        }
    }

    // MARK: - Two displays

    func testExternalAbove() {
        let external = display(2, -524, -1440, 2560, 1440)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .up)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: external, direction: .down)?.id, 1)
        XCTAssertNil(layout.neighbor(of: laptop, direction: .down))
        XCTAssertNil(layout.neighbor(of: laptop, direction: .left))
        XCTAssertNil(layout.neighbor(of: laptop, direction: .right))
    }

    func testExternalBelow() {
        let external = display(2, 200, 982, 1920, 1080)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .down)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: external, direction: .up)?.id, 1)
        XCTAssertNil(layout.neighbor(of: laptop, direction: .up))
    }

    func testExternalOnTheRight() {
        // Taller and slightly lower than the laptop: still "right", never "up".
        let external = display(2, 1512, 0, 1920, 1080)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .right)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: external, direction: .left)?.id, 1)
        XCTAssertNil(layout.neighbor(of: laptop, direction: .up))
        XCTAssertNil(layout.neighbor(of: laptop, direction: .down))
    }

    func testExternalOnTheLeft() {
        let external = display(2, -1920, -100, 1920, 1080)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .left)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: external, direction: .right)?.id, 1)
        XCTAssertNil(layout.neighbor(of: laptop, direction: .up))
    }

    func testExternalAboveWithPartialOverlap() {
        let external = display(2, 1000, -1080, 1920, 1080)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .up)?.id, 2)
        XCTAssertNil(layout.neighbor(of: laptop, direction: .right))
    }

    func testDiagonalExternalIsReachableFromBothSides() {
        // Touches the laptop only at its top-right corner.
        let external = display(2, 1512, -1080, 1920, 1080)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .up)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: laptop, direction: .right)?.id, 2)
        XCTAssertNil(layout.neighbor(of: laptop, direction: .down))
        XCTAssertNil(layout.neighbor(of: laptop, direction: .left))
    }

    // MARK: - Three displays

    func testThreeDisplaysPickTheOneInEachDirection() {
        let above = display(2, -524, -1440, 2560, 1440)
        let right = display(3, 1512, 0, 1920, 1080)
        let layout = DisplayLayout(displays: [laptop, above, right])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .up)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: laptop, direction: .right)?.id, 3)
        XCTAssertEqual(layout.neighbor(of: right, direction: .left)?.id, 1)
    }

    func testAlignedDisplayWinsOverDiagonalOne() {
        let diagonal = display(2, 1512, -1080, 1920, 1080)
        let above = display(3, 0, -1440, 1512, 1440)
        let layout = DisplayLayout(displays: [laptop, diagonal, above])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .up)?.id, 3)
    }

    func testNearestStackedDisplayWins() {
        let near = display(2, 0, -982, 1512, 982)
        let far = display(3, 0, -1964, 1512, 982)
        let layout = DisplayLayout(displays: [laptop, far, near])

        XCTAssertEqual(layout.neighbor(of: laptop, direction: .up)?.id, 2)
        XCTAssertEqual(layout.neighbor(of: near, direction: .up)?.id, 3)
    }

    // MARK: - Lookup

    func testDisplayContainingPoint() {
        let external = display(2, -524, -1440, 2560, 1440)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.display(containing: CGPoint(x: 700, y: 400))?.id, 1)
        XCTAssertEqual(layout.display(containing: CGPoint(x: 700, y: -400))?.id, 2)
    }

    func testDisplayContainingOffScreenPointFallsBackToNearest() {
        let external = display(2, -524, -1440, 2560, 1440)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.display(containing: CGPoint(x: 700, y: 5000))?.id, 1)
    }

    func testEmptyLayoutHasNoDisplay() {
        let layout = DisplayLayout(displays: [])

        XCTAssertNil(layout.display(containing: .zero))
        XCTAssertNil(layout.primary)
    }

    // MARK: - Description

    func testDirectionRelativeToPrimary() {
        let external = display(2, -524, -1440, 2560, 1440)
        let layout = DisplayLayout(displays: [laptop, external])

        XCTAssertEqual(layout.direction(of: external, relativeTo: laptop), .up)
        XCTAssertEqual(layout.direction(of: laptop, relativeTo: external), .down)
        XCTAssertNil(layout.direction(of: laptop, relativeTo: laptop))
    }

    func testSummary() {
        let external = display(2, -524, -1440, 2560, 1440, name: "DELL")

        XCTAssertEqual(DisplayLayout(displays: [laptop]).summary, "1 display: Built-in (primary)")
        XCTAssertEqual(DisplayLayout(displays: [laptop, external]).summary, "2 displays: Built-in (primary), DELL above")
    }
}
