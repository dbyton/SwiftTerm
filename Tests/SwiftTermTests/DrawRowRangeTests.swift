//
//  DrawRowRangeTests.swift
//
//  Regression test for the drawTerminalContents Double->Int crash:
//  "Double value cannot be converted to Int because the result would be less
//  than Int.min" raised from TerminalView.drawTerminalContents when AppKit hands
//  the view an unbounded dirtyRect (CGRectInfinite) or calls it pre-layout with a
//  non-positive cellHeight. `clampedVisibleRowRange` must clamp into the finite
//  view bounds instead of trapping the conversion.
//

#if os(macOS) || os(iOS) || os(visionOS)
import Foundation
import CoreGraphics
import Testing

@testable import SwiftTerm

struct DrawRowRangeTests {
    // A normal finite dirtyRect spanning the whole 100pt view with 10pt cells,
    // anchored at the top (maxY = 100), no scroll: the top of the dirty rect maps
    // to row 0 and the bottom to row 10.
    @Test func finiteRectProducesExpectedRows() {
        let r = clampedVisibleRowRange(
            dirtyMinY: 0, dirtyMaxY: 100,
            boundsMinY: 0, boundsMaxY: 100,
            anchorMaxY: 100, cellHeight: 10, yDisp: 0)
        #expect(r != nil)
        #expect(r?.firstRow == 0)
        #expect(r?.lastRow == 10)
        #expect((r?.firstRow ?? 1) <= (r?.lastRow ?? 0))
    }

    // CGRectInfinite (maxY/minY at ±greatestFiniteMagnitude) is what AppKit passes
    // on a full-view redraw. The previous inline `Int((anchorMaxY - dirtyRect.maxY)
    // / cellHeight)` trapped here; the clamped version must return a valid range.
    @Test func infiniteDirtyRectDoesNotTrap() {
        let inf = CGRect.infinite
        let r = clampedVisibleRowRange(
            dirtyMinY: inf.minY, dirtyMaxY: inf.maxY,
            boundsMinY: 0, boundsMaxY: 100,
            anchorMaxY: 100, cellHeight: 10, yDisp: 5)
        #expect(r != nil)
        #expect((r?.firstRow ?? 1) <= (r?.lastRow ?? 0))
    }

    // Literal infinities and NaN must also be handled (some layer-backed display
    // passes / degenerate geometry).
    @Test func nonFiniteCoordinatesDoNotTrap() {
        for (mn, mx) in [(CGFloat.nan, CGFloat.nan),
                         (-CGFloat.infinity, CGFloat.infinity),
                         (CGFloat.nan, CGFloat.infinity)] {
            let r = clampedVisibleRowRange(
                dirtyMinY: mn, dirtyMaxY: mx,
                boundsMinY: 0, boundsMaxY: 100,
                anchorMaxY: 100, cellHeight: 10, yDisp: 0)
            #expect(r != nil)
            #expect((r?.firstRow ?? 1) <= (r?.lastRow ?? 0))
        }
    }

    // A pre-layout draw can produce cellHeight <= 0; there is nothing to draw, so
    // return nil rather than divide by zero and trap.
    @Test func nonPositiveCellHeightReturnsNil() {
        #expect(clampedVisibleRowRange(
            dirtyMinY: 0, dirtyMaxY: 100, boundsMinY: 0, boundsMaxY: 100,
            anchorMaxY: 100, cellHeight: 0, yDisp: 0) == nil)
        #expect(clampedVisibleRowRange(
            dirtyMinY: 0, dirtyMaxY: 100, boundsMinY: 0, boundsMaxY: 100,
            anchorMaxY: 100, cellHeight: -5, yDisp: 0) == nil)
    }

    // Non-finite view bounds / anchor are unusable; bail rather than trap.
    @Test func nonFiniteBoundsReturnNil() {
        #expect(clampedVisibleRowRange(
            dirtyMinY: 0, dirtyMaxY: 100, boundsMinY: 0, boundsMaxY: .infinity,
            anchorMaxY: 100, cellHeight: 10, yDisp: 0) == nil)
        #expect(clampedVisibleRowRange(
            dirtyMinY: 0, dirtyMaxY: 100, boundsMinY: 0, boundsMaxY: 100,
            anchorMaxY: .nan, cellHeight: 10, yDisp: 0) == nil)
    }
}
#endif
