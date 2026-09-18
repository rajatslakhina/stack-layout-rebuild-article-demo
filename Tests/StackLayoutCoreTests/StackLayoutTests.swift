import XCTest
@testable import StackLayoutCore

final class StackLayoutTests: XCTestCase {

    // MARK: - The headline scenario

    func testFlexibilityOrderedFitsTheToolbarRowExactly() throws {
        let scenario = try XCTUnwrap(
            ScenarioLibrary.all.first { $0.id == "toolbar-icon-title-spacer" }
        )
        let result = scenario.result(using: .flexibilityOrdered)

        XCTAssertEqual(result.frames.count, 3)
        XCTAssertEqual(result.frames[0].width, 120, accuracy: 0.001, "the icon keeps its intrinsic width")
        XCTAssertEqual(result.frames[1].width, 92, accuracy: 0.001, "the title takes half of what is left")
        XCTAssertEqual(result.frames[2].width, 92, accuracy: 0.001, "the spacer takes the remainder")
        XCTAssertEqual(result.usedWidth, 320, accuracy: 0.001)
        XCTAssertEqual(result.overflow, 0, accuracy: 0.001)
    }

    func testEvenSplitOverflowsTheSameToolbarRow() throws {
        let scenario = try XCTUnwrap(
            ScenarioLibrary.all.first { $0.id == "toolbar-icon-title-spacer" }
        )
        let result = scenario.result(using: .evenSplit)

        // 320 - 2*8 spacing = 304 available, 304/3 = 101.333 proposed to each.
        // The 120pt icon refuses, and nobody gives anything back.
        XCTAssertEqual(result.frames[0].width, 120, accuracy: 0.001)
        XCTAssertEqual(result.frames[1].width, 101.3333, accuracy: 0.001)
        XCTAssertEqual(result.frames[2].width, 101.3333, accuracy: 0.001)
        XCTAssertEqual(result.overflow, 18.6666, accuracy: 0.001)
    }

    // MARK: - Ordering

    func testLeastFlexibleChildIsSizedFirst() {
        // A greedy spacer declared first must not eat the fixed child's width.
        let children: [LayoutChild] = [
            .flexible(name: "Spacer", minWidth: 0, maxWidth: .infinity),
            .fixed(name: "Pinned", width: 150)
        ]
        let layout = StackLayout(spacing: 0)
        let result = layout.frames(for: children, in: 200, using: .flexibilityOrdered)

        XCTAssertEqual(result.frames[1].width, 150, accuracy: 0.001)
        XCTAssertEqual(result.frames[0].width, 50, accuracy: 0.001)
        XCTAssertEqual(result.overflow, 0, accuracy: 0.001)
    }

    func testFramesAreReturnedInDeclarationOrderNotSizingOrder() {
        let children: [LayoutChild] = [
            .flexible(name: "Spacer", minWidth: 0, maxWidth: .infinity),
            .fixed(name: "Pinned", width: 150)
        ]
        let result = StackLayout(spacing: 0)
            .frames(for: children, in: 200, using: .flexibilityOrdered)

        XCTAssertEqual(result.frames.map(\.name), ["Spacer", "Pinned"])
        XCTAssertEqual(result.frames[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(result.frames[1].x, 50, accuracy: 0.001)
    }

    func testEqualFlexibilityTiesFallBackToDeclarationOrder() {
        // Both children are identical, so the result must be symmetric and
        // must not depend on how the sort happens to break ties.
        let children: [LayoutChild] = [
            .text(name: "Left", minWidth: 40, idealWidth: 160),
            .text(name: "Right", minWidth: 40, idealWidth: 160)
        ]
        let result = StackLayout(spacing: 8)
            .frames(for: children, in: 300, using: .flexibilityOrdered)

        XCTAssertEqual(result.frames[0].width, result.frames[1].width, accuracy: 0.001)
        XCTAssertEqual(result.frames[0].width, 146, accuracy: 0.001)
    }

    // MARK: - Edge cases

    func testEmptyStackProducesNoFramesAndDoesNotCrash() {
        for strategy in AllocationStrategy.allCases {
            let result = StackLayout(spacing: 8)
                .frames(for: [], in: 300, using: strategy)
            XCTAssertTrue(result.frames.isEmpty)
            XCTAssertEqual(result.usedWidth, 0, accuracy: 0.001)
            XCTAssertEqual(result.overflow, 0, accuracy: 0.001)
        }
    }

    func testSpacingLargerThanContainerClampsAvailableWidthAtZero() {
        // 3 children, 24pt spacing, 40pt container: the gaps alone are 48pt.
        let children: [LayoutChild] = [
            .text(name: "A", minWidth: 10, idealWidth: 60),
            .text(name: "B", minWidth: 10, idealWidth: 60),
            .text(name: "C", minWidth: 10, idealWidth: 60)
        ]
        for strategy in AllocationStrategy.allCases {
            let result = StackLayout(spacing: 24)
                .frames(for: children, in: 40, using: strategy)
            for frame in result.frames {
                XCTAssertEqual(frame.width, 10, accuracy: 0.001, "every child falls back to its minimum")
                XCTAssertGreaterThanOrEqual(frame.width, 0)
            }
        }
    }

    func testNegativeAndNaNInputsAreSanitisedRatherThanPropagated() {
        let poisoned: [LayoutChild] = [
            .fixed(name: "Negative", width: -50),
            .text(name: "NaN", minWidth: .nan, idealWidth: 100),
            .flexible(name: "Reversed", minWidth: 90, maxWidth: 10)
        ]
        let result = StackLayout(spacing: .nan)
            .frames(for: poisoned, in: .nan, using: .flexibilityOrdered)

        for frame in result.frames {
            XCTAssertFalse(frame.width.isNaN, "\(frame.name) produced NaN")
            XCTAssertGreaterThanOrEqual(frame.width, 0)
            XCTAssertFalse(frame.x.isNaN)
        }
        XCTAssertEqual(result.frames[0].width, 0, accuracy: 0.001)
        // Reversed bounds: the maximum is raised to the minimum, so the child
        // reports 90 rather than an impossible range.
        XCTAssertEqual(result.frames[2].width, 90, accuracy: 0.001)
    }

    func testFullyFlexibleChildTakesTheWholeContainer() {
        for strategy in AllocationStrategy.allCases {
            let result = StackLayout(spacing: 8)
                .frames(for: [.flexible(name: "Fill", minWidth: 0, maxWidth: .infinity)],
                        in: 300, using: strategy)
            XCTAssertEqual(result.frames[0].width, 300, accuracy: 0.001)
        }
    }

    func testFlexibilityOfAnUnboundedChildIsInfiniteAndNotNaN() {
        let spacer = LayoutChild.flexible(name: "Spacer", minWidth: 0, maxWidth: .infinity)
        XCTAssertTrue(spacer.flexibility.isInfinite)
        XCTAssertFalse(spacer.flexibility.isNaN)

        let fixed = LayoutChild.fixed(name: "Icon", width: 44)
        XCTAssertEqual(fixed.flexibility, 0, accuracy: 0.001)

        let label = LayoutChild.text(name: "Label", minWidth: 40, idealWidth: 200)
        XCTAssertEqual(label.flexibility, 160, accuracy: 0.001)
    }

    func testNoChildIsEverAllocatedANegativeWidth() {
        for scenario in ScenarioLibrary.all {
            for strategy in AllocationStrategy.allCases {
                for frame in scenario.result(using: strategy).frames {
                    XCTAssertGreaterThanOrEqual(
                        frame.width, 0,
                        "\(scenario.id)/\(strategy.rawValue)/\(frame.name)"
                    )
                }
            }
        }
    }

    func testFlexibilityOrderedNeverOverflowsWhenTheMinimumsFit() {
        // If the sum of minimum widths plus spacing fits, the ordered rule
        // must fit too. This is the invariant that makes it safe to ship.
        for scenario in ScenarioLibrary.all where !scenario.children.isEmpty {
            let gaps = scenario.spacing * Double(scenario.children.count - 1)
            let minimums = scenario.children.reduce(0) { $0 + $1.width(for: .zero) }
            guard minimums + gaps <= scenario.containerWidth else { continue }
            let result = scenario.result(using: .flexibilityOrdered)
            XCTAssertEqual(result.overflow, 0, accuracy: 0.001, "overflowed \(scenario.id)")
        }
    }
}
