#if os(macOS)
import CoreGraphics

/// Axis a scroll gesture has been locked to. Held across a trackpad gesture
/// (including its momentum tail) so a jittery mid-gesture delta cannot flip
/// routing — the historical "horizontal swipe suddenly scrolls vertically"
/// failure mode when scrolling a horizontal pane strip over a terminal.
enum ScrollRoutingAxis: Equatable {
    case undetermined
    case horizontal
    case vertical
}

/// Outcome of routing one `scrollWheel` event.
struct ScrollRoutingDecision: Equatable {
    /// Forward the event up the responder chain (an enclosing scroll view
    /// handles it) instead of scrolling the terminal grid.
    var forwardUpResponderChain: Bool
    /// Axis to remember for the rest of the current gesture.
    var lockedAxis: ScrollRoutingAxis
}

/// Pure routing decision for one `scrollWheel` event. The caller extracts the
/// primitive inputs from the `NSEvent` so this stays unit-testable without an
/// AppKit view hierarchy.
///
/// - Parameters:
///   - scrollingDeltaX/Y: the precise (pixel) scroll deltas.
///   - legacyDeltaY: `NSEvent.deltaY` — line-based; `0` for pure-horizontal.
///   - isGesture: a trackpad gesture (has a phase / momentum phase).
///   - isGestureClassificationPoint: the first event with real motion this
///     gesture (`phase == .began`, or `.changed` while still undetermined).
///   - isGestureEnd: the gesture (incl. momentum) has finished.
///   - lockedAxis: the axis locked so far this gesture.
///   - horizontalBias: how much `deltaX` must exceed `deltaY` to count as a
///     horizontal scroll. `1.5` keeps intent-vertical diagonals on the grid.
func scrollRoutingDecision(
    scrollingDeltaX dx: CGFloat,
    scrollingDeltaY dy: CGFloat,
    legacyDeltaY: CGFloat,
    isGesture: Bool,
    isGestureClassificationPoint: Bool,
    isGestureEnd: Bool,
    lockedAxis: ScrollRoutingAxis,
    horizontalBias: CGFloat = 1.5
) -> ScrollRoutingDecision {
    // A pure-horizontal event (some vertical-free motion, no `deltaY` at all)
    // is never something the terminal grid consumes — forward it regardless of
    // gesture classification. This is the event the terminal historically
    // dropped outright, so pure-horizontal pane-strip swipes did nothing.
    let isPureHorizontal = legacyDeltaY == 0 && abs(dx) > 0

    if isGesture {
        var axis = lockedAxis
        // Lock the axis once, on the first event with real motion, and hold it
        // for the rest of the gesture so a jittery delta cannot flip routing.
        if isGestureClassificationPoint {
            if abs(dx) > abs(dy) * horizontalBias {
                axis = .horizontal
            } else if abs(dy) > 0.5 {
                axis = .vertical
            }
        }

        let forward: Bool
        switch axis {
        case .horizontal: forward = true
        case .vertical: forward = false
        case .undetermined: forward = isPureHorizontal
        }

        // Clear the lock only once the whole gesture (including its momentum
        // tail) has ended, so momentum events stay routed in the locked axis.
        return ScrollRoutingDecision(
            forwardUpResponderChain: forward,
            lockedAxis: isGestureEnd ? .undetermined : axis)
    }

    // Mouse wheel (no gesture phase): classify each event independently.
    let forward = isPureHorizontal || abs(dx) > abs(dy) * horizontalBias
    return ScrollRoutingDecision(forwardUpResponderChain: forward, lockedAxis: .undetermined)
}
#endif
