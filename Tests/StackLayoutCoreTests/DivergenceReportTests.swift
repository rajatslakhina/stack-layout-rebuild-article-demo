import XCTest
@testable import StackLayoutCore

/// These tests pin the numbers quoted in the README and the article.
/// If the scenario suite or either allocation rule changes, the prose breaks
/// loudly here rather than quietly in public.
final class DivergenceReportTests: XCTestCase {

    private let report = DivergenceReport.compare()

    func testSuiteSizeIsTwentyFourScenarios() {
        XCTAssertEqual(report.count, 24)
        XCTAssertEqual(ScenarioLibrary.all.count, 24)
    }

    func testScenarioIdentifiersAreUnique() {
        let ids = Set(ScenarioLibrary.all.map(\.id))
        XCTAssertEqual(ids.count, ScenarioLibrary.all.count)
    }

    func testChildNamesAreUniqueWithinEachScenario() {
        // Frame identity in the demo UI depends on this.
        for scenario in ScenarioLibrary.all {
            let names = Set(scenario.children.map(\.name))
            XCTAssertEqual(names.count, scenario.children.count, scenario.id)
        }
    }

    func testFourteenOfTwentyFourScenariosDiverge() {
        let summary = DivergenceReport.summary(for: report)
        XCTAssertEqual(summary.total, 24)
        XCTAssertEqual(summary.divergent, 14)
        XCTAssertEqual(summary.identical, 10)
    }

    func testWorstExtraOverflowIsTheToolbarRow() {
        let summary = DivergenceReport.summary(for: report)
        XCTAssertEqual(summary.worstScenarioID, "toolbar-icon-title-spacer")
        XCTAssertEqual(summary.worstExtraOverflow, 18.6666, accuracy: 0.001)
    }

    func testWorstSingleChildDifferenceIsTheTruncatedHeadline() throws {
        let summary = DivergenceReport.summary(for: report)
        XCTAssertEqual(summary.worstWidthDelta, 161.3333, accuracy: 0.001)

        let worst = try XCTUnwrap(report.first { $0.scenario.id == "badge-then-long-text" })
        XCTAssertEqual(worst.maxWidthDelta, 161.3333, accuracy: 0.001)
        XCTAssertEqual(worst.divergentChildren, ["Headline"])

        // The headline is the point: the even split does not overflow here.
        // It under-fills, and the label truncates 161pt early.
        XCTAssertEqual(worst.evenSplit.overflow, 0, accuracy: 0.001)
        XCTAssertEqual(worst.ordered.frames[1].width, 266, accuracy: 0.001)
        XCTAssertEqual(worst.evenSplit.frames[1].width, 104.6666, accuracy: 0.001)
    }

    func testTwelveOfTheFourteenDivergencesAreInvisibleToAnOverflowCheck() {
        let divergent = report.filter { !$0.isIdentical }
        XCTAssertEqual(divergent.count, 14)

        let clean = divergent.filter { $0.evenSplit.overflow <= DivergenceReport.tolerance }
        XCTAssertEqual(
            clean.count, 12,
            "a checker that only asks 'did it overflow' misses these"
        )

        let visible = divergent.filter { $0.evenSplit.overflow > DivergenceReport.tolerance }
        XCTAssertEqual(Set(visible.map(\.scenario.id)),
                       ["toolbar-icon-title-spacer", "one-greedy-two-rigid"])
    }

    func testTheEvenSplitOverflowsFourScenariosAndTheOrderedRuleTwo() {
        let evenOverflows = report.filter { $0.evenSplit.overflow > DivergenceReport.tolerance }
        let orderedOverflows = report.filter { $0.ordered.overflow > DivergenceReport.tolerance }
        XCTAssertEqual(evenOverflows.count, 4)
        XCTAssertEqual(orderedOverflows.count, 2)

        // Both of the ordered rule's overflows are scenarios where the
        // minimum widths genuinely do not fit, so no rule could have avoided
        // them. That is the difference between a limit and a bug.
        XCTAssertEqual(Set(orderedOverflows.map(\.scenario.id)),
                       ["three-buttons-tight", "spacing-exceeds-container"])
        for divergence in orderedOverflows {
            let scenario = divergence.scenario
            let gaps = scenario.spacing * Double(max(0, scenario.children.count - 1))
            let minimums = scenario.children.reduce(0) { $0 + $1.width(for: .zero) }
            XCTAssertGreaterThan(minimums + gaps, scenario.containerWidth, scenario.id)
        }
    }

    /// Literal expected widths for every scenario the two rules agree on.
    ///
    /// Asserting `isIdentical` implies identical frames would be vacuous —
    /// `isIdentical` is *defined* as "no width differs by more than
    /// `tolerance`". These are the actual numbers instead, so gutting the
    /// allocator fails the test.
    private static let agreedWidths: [String: [Double]] = [
        "two-labels-equal": [146, 146],
        "three-buttons-tight": [100, 90, 96],
        "single-fixed": [140],
        "single-flexible": [300],
        "empty-stack": [],
        "spacing-exceeds-container": [10, 10, 10],
        "wide-container-all-satisfied": [120, 120, 120],
        "stepper-row": [32, 40, 32],
        "min-width-floor-bites": [126, 126],
        "exact-fit": [100, 100, 100]
    ]

    func testEveryAgreedScenarioProducesItsExpectedWidthsUnderBothRules() {
        let identical = report.filter(\.isIdentical).map(\.scenario.id)
        XCTAssertEqual(Set(identical), Set(Self.agreedWidths.keys),
                       "the set of scenarios the two rules agree on has changed")

        for divergence in report where divergence.isIdentical {
            guard let expected = Self.agreedWidths[divergence.scenario.id] else {
                XCTFail("no expectation for \(divergence.scenario.id)")
                continue
            }
            for result in [divergence.ordered, divergence.evenSplit] {
                XCTAssertEqual(result.frames.count, expected.count, divergence.scenario.id)
                guard result.frames.count == expected.count else { continue }
                for index in expected.indices {
                    XCTAssertEqual(result.frames[index].width, expected[index],
                                   accuracy: 0.001,
                                   "\(divergence.scenario.id)[\(index)]")
                }
            }
        }
    }

    func testSummaryOfAnEmptySuiteIsZeroedRatherThanCrashing() {
        let summary = DivergenceReport.summary(for: [])
        XCTAssertEqual(summary.total, 0)
        XCTAssertEqual(summary.divergent, 0)
        XCTAssertEqual(summary.identical, 0)
        XCTAssertNil(summary.worstScenarioID)
        XCTAssertEqual(summary.worstExtraOverflow, 0, accuracy: 0.001)
        XCTAssertEqual(summary.worstWidthDelta, 0, accuracy: 0.001)
    }

    func testDivergenceComparisonHandlesScenariosWithNoChildren() throws {
        let empty = try XCTUnwrap(report.first { $0.scenario.id == "empty-stack" })
        XCTAssertTrue(empty.isIdentical)
        XCTAssertTrue(empty.divergentChildren.isEmpty)
        XCTAssertEqual(empty.maxWidthDelta, 0, accuracy: 0.001)
    }
}
