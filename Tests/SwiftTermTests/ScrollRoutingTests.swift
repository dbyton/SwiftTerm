#if os(macOS)
import Testing
import CoreGraphics
@testable import SwiftTerm

/// Unit coverage for `scrollRoutingDecision` — the pure logic that decides
/// whether a `scrollWheel` event belongs to the terminal grid or should be
/// forwarded up the responder chain to an enclosing scroll view (e.g. a
/// horizontal pane strip). The actual responder-chain delivery is exercised
/// at runtime by the host app.
struct ScrollRoutingTests {

    // MARK: Mouse wheel (no gesture phase) — classify per event.

    @Test func horizontalMouseWheelForwardsUpChain() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: -40, scrollingDeltaY: 0, legacyDeltaY: 0,
            isGesture: false, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == true)
    }

    @Test func verticalMouseWheelStaysOnGrid() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 0, scrollingDeltaY: -30, legacyDeltaY: -3,
            isGesture: false, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == false)
    }

    /// A gentle diagonal (horizontal not clearly dominant) stays on the grid,
    /// preserving the historical 1.5x dead zone so intent-vertical swipes
    /// scroll scrollback rather than the pane strip.
    @Test func gentleDiagonalStaysOnGrid() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 12, scrollingDeltaY: 10, legacyDeltaY: 1,
            isGesture: false, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == false)
    }

    /// A pure-horizontal event (no vertical component at all) is forwarded —
    /// this is the case the terminal historically dropped outright, which is
    /// why pure-horizontal pane-strip swipes did nothing.
    @Test func pureHorizontalMouseWheelForwards() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 18, scrollingDeltaY: 0, legacyDeltaY: 0,
            isGesture: false, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == true)
    }

    // MARK: Trackpad gesture — axis is locked at the start and held.

    @Test func gestureLocksHorizontalAtStart() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: -40, scrollingDeltaY: 5, legacyDeltaY: 0,
            isGesture: true, isGestureClassificationPoint: true,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == true)
        #expect(d.lockedAxis == .horizontal)
    }

    @Test func gestureLocksVerticalAtStart() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 5, scrollingDeltaY: -40, legacyDeltaY: -4,
            isGesture: true, isGestureClassificationPoint: true,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == false)
        #expect(d.lockedAxis == .vertical)
    }

    /// The load-bearing anti-jitter guarantee: once a gesture is locked
    /// horizontal, a jittery mid-gesture event whose vertical delta momentarily
    /// dominates must NOT flip routing back to the grid.
    @Test func horizontalLockHoldsThroughVerticalJitter() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 2, scrollingDeltaY: 18, legacyDeltaY: 2,
            isGesture: true, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .horizontal)
        #expect(d.forwardUpResponderChain == true)
        #expect(d.lockedAxis == .horizontal)
    }

    @Test func verticalLockHoldsThroughHorizontalJitter() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 18, scrollingDeltaY: 2, legacyDeltaY: 2,
            isGesture: true, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .vertical)
        #expect(d.forwardUpResponderChain == false)
        #expect(d.lockedAxis == .vertical)
    }

    /// When the whole gesture (including momentum) ends, the lock clears so the
    /// next gesture re-classifies from scratch.
    @Test func gestureEndClearsLock() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: 2, scrollingDeltaY: 18, legacyDeltaY: 2,
            isGesture: true, isGestureClassificationPoint: false,
            isGestureEnd: true, lockedAxis: .horizontal)
        #expect(d.lockedAxis == .undetermined)
    }

    /// Before a gesture classifies, a pure-horizontal event still forwards
    /// (vertical-with-no-classification stays on the grid by default).
    @Test func pureHorizontalForwardsBeforeClassification() {
        let d = scrollRoutingDecision(
            scrollingDeltaX: -25, scrollingDeltaY: 0, legacyDeltaY: 0,
            isGesture: true, isGestureClassificationPoint: false,
            isGestureEnd: false, lockedAxis: .undetermined)
        #expect(d.forwardUpResponderChain == true)
    }
}
#endif
