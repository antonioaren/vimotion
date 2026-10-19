import CoreGraphics
import Foundation

/// A value type describing a connected display. Pure data, so the layout logic
/// can be unit-tested with synthetic arrangements.
///
/// `frame` uses the same **top-left origin** convention as `WindowInfo`, so the
/// primary display sits at (0, 0) and a display arranged above it in System
/// Settings has a negative `y`.
public struct DisplayInfo: Equatable, Sendable {
    /// Core Graphics display id (stable while the display stays connected).
    public let id: CGDirectDisplayID
    /// Display rectangle in global, top-left-origin coordinates.
    public let frame: CGRect
    /// Whether this is the main display (the one holding the menu bar).
    public let isPrimary: Bool
    /// Human-readable name (e.g. "Built-in Retina Display").
    public let name: String

    public init(id: CGDirectDisplayID, frame: CGRect, isPrimary: Bool = false, name: String = "") {
        self.id = id
        self.frame = frame
        self.isPrimary = isPrimary
        self.name = name
    }

    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// The arrangement of all connected displays, as configured in macOS. Answers
/// "which display holds this point?" and "which display is next to this one in
/// a given direction?".
public struct DisplayLayout: Sendable {

    public let displays: [DisplayInfo]

    /// Slack (in points) when deciding whether two display edges touch or
    /// overlap, to absorb rounding in the reported frames.
    private let edgeTolerance: CGFloat

    public init(displays: [DisplayInfo], edgeTolerance: CGFloat = 2) {
        self.displays = displays
        self.edgeTolerance = edgeTolerance
    }

    public var primary: DisplayInfo? {
        displays.first(where: { $0.isPrimary }) ?? displays.first
    }

    public func display(withID id: CGDirectDisplayID) -> DisplayInfo? {
        displays.first(where: { $0.id == id })
    }

    /// The display containing `point`, or the one whose center is nearest when
    /// the point falls outside every display (e.g. a window dragged off-screen).
    public func display(containing point: CGPoint) -> DisplayInfo? {
        if let match = displays.first(where: { $0.frame.contains(point) }) {
            return match
        }
        return displays.min(by: { distance($0.center, point) < distance($1.center, point) })
    }

    /// The display adjacent to `source` in `direction`, or `nil` if there is
    /// none.
    ///
    /// Candidates must lie beyond the corresponding edge of `source` (for
    /// `.up`, entirely above its top edge). Displays that overlap `source` on
    /// the perpendicular axis win over diagonal ones; ties are broken by the
    /// smallest gap and then by the largest overlap. Diagonal displays are
    /// ranked by their combined edge distance.
    public func neighbor(of source: DisplayInfo, direction: Direction) -> DisplayInfo? {
        var best: DisplayInfo?
        // (tier, distance, -overlap), compared lexicographically.
        var bestRank: (Int, CGFloat, CGFloat)?

        for candidate in displays where candidate.id != source.id {
            guard let m = metrics(from: source, to: candidate, direction: direction) else { continue }

            let aligned = m.overlap > edgeTolerance
            let rank: (Int, CGFloat, CGFloat) = (
                aligned ? 0 : 1,
                aligned ? m.gap : m.gap + m.perpendicularGap,
                -m.overlap
            )
            if let current = bestRank, !(rank < current) { continue }
            bestRank = rank
            best = candidate
        }
        return best
    }

    /// Where `display` sits relative to `reference` (e.g. `.up` for a monitor
    /// arranged above the laptop), or `nil` if they can't be compared.
    public func direction(of display: DisplayInfo, relativeTo reference: DisplayInfo) -> Direction? {
        guard display.id != reference.id else { return nil }

        var best: Direction?
        // (tier, -overlap), compared lexicographically.
        var bestRank: (Int, CGFloat)?
        for direction in Direction.allCases {
            guard let m = metrics(from: reference, to: display, direction: direction) else { continue }
            let rank: (Int, CGFloat) = (m.overlap > edgeTolerance ? 0 : 1, -m.overlap)
            if let current = bestRank, !(rank < current) { continue }
            bestRank = rank
            best = direction
        }
        return best
    }

    /// One-line description such as
    /// "2 displays: Built-in Retina Display (primary), DELL U2720Q above".
    public var summary: String {
        guard !displays.isEmpty else { return "No displays" }
        let count = displays.count == 1 ? "1 display" : "\(displays.count) displays"
        let primary = self.primary
        let parts = displays.map { display -> String in
            let name = display.name.isEmpty ? "Display \(display.id)" : display.name
            if display.id == primary?.id { return "\(name) (primary)" }
            guard let primary, let position = self.direction(of: display, relativeTo: primary) else { return name }
            return "\(name) \(Self.positionWord(position))"
        }
        return "\(count): " + parts.joined(separator: ", ")
    }

    // MARK: - Geometry

    private struct Metrics {
        /// Distance between the facing edges along the movement axis.
        let gap: CGFloat
        /// Overlap of both displays on the perpendicular axis.
        let overlap: CGFloat
        /// Distance between both displays on the perpendicular axis (0 when
        /// they overlap).
        let perpendicularGap: CGFloat
    }

    /// Edge metrics from `s` to `t` in `direction`, or `nil` when `t` does not
    /// lie beyond the corresponding edge of `s`.
    private func metrics(from s: DisplayInfo, to t: DisplayInfo, direction: Direction) -> Metrics? {
        let a = s.frame
        let b = t.frame

        let gap: CGFloat
        let centerDelta: CGFloat
        switch direction {
        case .up:
            gap = a.minY - b.maxY
            centerDelta = a.midY - b.midY
        case .down:
            gap = b.minY - a.maxY
            centerDelta = b.midY - a.midY
        case .left:
            gap = a.minX - b.maxX
            centerDelta = a.midX - b.midX
        case .right:
            gap = b.minX - a.maxX
            centerDelta = b.midX - a.midX
        }
        guard centerDelta > 0, gap >= -edgeTolerance else { return nil }

        let (aLo, aHi, bLo, bHi) = direction.isHorizontal
            ? (a.minY, a.maxY, b.minY, b.maxY)
            : (a.minX, a.maxX, b.minX, b.maxX)
        let overlap = max(0, min(aHi, bHi) - max(aLo, bLo))
        let perpendicularGap = max(0, max(aLo, bLo) - min(aHi, bHi))

        return Metrics(gap: max(0, gap), overlap: overlap, perpendicularGap: perpendicularGap)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func positionWord(_ direction: Direction) -> String {
        switch direction {
        case .up: return "above"
        case .down: return "below"
        case .left: return "on the left"
        case .right: return "on the right"
        }
    }
}
