import CoreGraphics
import Foundation

/// Pure, side-effect-free logic that picks the best window to focus when moving
/// in a given direction from a source window.
///
/// The algorithm is intentionally simple and predictable:
///
/// 1. Discard the source window and any window not in the requested half-plane
///    (e.g. for `.right`, only windows whose center is to the right of the
///    source center are considered).
/// 2. Score each remaining candidate by a cost that combines the travel
///    distance along the movement axis with a penalty for misalignment on the
///    perpendicular axis. Windows that overlap the source on the perpendicular
///    axis (i.e. are "in line" with it) are rewarded.
/// 3. Pick the lowest-cost candidate.
///
/// Because it only consumes `[WindowInfo]` values, it can be unit-tested with
/// synthetic layouts and has no dependency on AppKit.
public struct DirectionalNavigator {

    /// Weight applied to perpendicular misalignment. Higher values bias the
    /// selection toward windows that are well aligned with the source along the
    /// movement axis. Tunable (see TASK T6.1).
    private let perpendicularWeight: CGFloat

    /// Minimum movement along the axis (in points) for a window to count as
    /// being "in the direction", to ignore near-coincident centers.
    private let axisEpsilon: CGFloat

    public init(perpendicularWeight: CGFloat = 2.0, axisEpsilon: CGFloat = 1.0) {
        self.perpendicularWeight = perpendicularWeight
        self.axisEpsilon = axisEpsilon
    }

    /// Returns the best window to focus when moving `direction` from `source`.
    /// `candidates` may include the source; it is filtered out. Returns `nil`
    /// when there is no window in that direction.
    public func nextWindow(
        from source: WindowInfo,
        direction: Direction,
        candidates: [WindowInfo]
    ) -> WindowInfo? {
        var best: WindowInfo?
        var bestCost = CGFloat.greatestFiniteMagnitude

        for candidate in candidates where candidate.id != source.id {
            guard let cost = cost(from: source, to: candidate, direction: direction) else {
                continue
            }
            if cost < bestCost {
                bestCost = cost
                best = candidate
            }
        }
        return best
    }

    /// Convenience overload: locate the source by id inside `candidates`.
    public func nextWindow(
        fromID sourceID: CGWindowID,
        direction: Direction,
        candidates: [WindowInfo]
    ) -> WindowInfo? {
        guard let source = candidates.first(where: { $0.id == sourceID }) else {
            return nil
        }
        return nextWindow(from: source, direction: direction, candidates: candidates)
    }

    // MARK: - Cost

    /// Cost of moving from `s` to `t` in `direction`, or `nil` if `t` is not in
    /// that direction.
    private func cost(from s: WindowInfo, to t: WindowInfo, direction: Direction) -> CGFloat? {
        let dx = t.center.x - s.center.x
        let dy = t.center.y - s.center.y

        // Project the center delta onto the movement axis (primary) and the
        // perpendicular axis, in the top-left coordinate convention.
        let primaryDelta: CGFloat
        let perpDelta: CGFloat
        switch direction {
        case .left:
            primaryDelta = -dx
            perpDelta = dy
        case .right:
            primaryDelta = dx
            perpDelta = dy
        case .up:
            primaryDelta = -dy
            perpDelta = dx
        case .down:
            primaryDelta = dy
            perpDelta = dx
        }

        // The candidate must actually lie in the requested direction.
        guard primaryDelta > axisEpsilon else { return nil }

        // Reward windows that overlap the source on the perpendicular axis: an
        // overlapping window is "in line" with the source and should be
        // preferred even if its center is slightly offset.
        let overlap = perpendicularOverlap(s, t, isHorizontalMove: direction.isHorizontal)
        let effectivePerp = max(0, abs(perpDelta) - overlap * 0.5)

        return primaryDelta + perpendicularWeight * effectivePerp
    }

    /// Length of overlap between the two windows along the axis perpendicular to
    /// the movement (the vertical extent for a horizontal move, and vice versa).
    private func perpendicularOverlap(
        _ a: WindowInfo,
        _ b: WindowInfo,
        isHorizontalMove: Bool
    ) -> CGFloat {
        if isHorizontalMove {
            let lo = max(a.frame.minY, b.frame.minY)
            let hi = min(a.frame.maxY, b.frame.maxY)
            return max(0, hi - lo)
        } else {
            let lo = max(a.frame.minX, b.frame.minX)
            let hi = min(a.frame.maxX, b.frame.maxX)
            return max(0, hi - lo)
        }
    }
}
