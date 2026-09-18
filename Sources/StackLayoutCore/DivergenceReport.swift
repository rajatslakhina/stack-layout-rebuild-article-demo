import Foundation

/// What the two allocation rules did to one scenario.
public struct ScenarioDivergence: Sendable, Hashable, Identifiable {
    public let scenario: Scenario
    public let ordered: LayoutResult
    public let evenSplit: LayoutResult
    /// Largest per-child difference in width, in points.
    public let maxWidthDelta: Double
    /// Points by which the even split runs past the container beyond whatever
    /// the flexibility-ordered rule already overflowed. Zero when even split
    /// is no worse.
    public let extraOverflow: Double
    public let isIdentical: Bool

    public var id: String { scenario.id }

    /// Names of the children whose width differs between the two rules.
    public let divergentChildren: [String]
}

/// Runs both allocation rules over a scenario suite and reports where they
/// part company.
///
/// This is the instrument the whole exercise exists to produce: not an
/// argument that one rule is better, but a list of the specific inputs on
/// which choosing wrong is visible.
public enum DivergenceReport {
    /// Two widths within this many points are treated as the same width.
    /// A half-point is below the smallest visible difference on a 3x display.
    public static let tolerance: Double = 0.5

    public static func compare(_ scenario: Scenario) -> ScenarioDivergence {
        let ordered = scenario.result(using: .flexibilityOrdered)
        let even = scenario.result(using: .evenSplit)

        var maxDelta = 0.0
        var divergent: [String] = []
        let pairCount = Swift.min(ordered.frames.count, even.frames.count)
        for index in 0..<pairCount {
            let a = ordered.frames[index]
            let b = even.frames[index]
            let delta = abs(a.width - b.width)
            if delta > maxDelta { maxDelta = delta }
            if delta > tolerance { divergent.append(a.name) }
        }

        return ScenarioDivergence(
            scenario: scenario,
            ordered: ordered,
            evenSplit: even,
            maxWidthDelta: maxDelta,
            extraOverflow: Swift.max(0, even.overflow - ordered.overflow),
            isIdentical: divergent.isEmpty,
            divergentChildren: divergent
        )
    }

    public static func compare(_ scenarios: [Scenario] = ScenarioLibrary.all) -> [ScenarioDivergence] {
        scenarios.map(compare)
    }

    /// Headline numbers for a whole suite.
    public struct Summary: Sendable, Hashable {
        public let total: Int
        public let identical: Int
        public let divergent: Int
        /// The worst extra overflow the even split produced, in points.
        public let worstExtraOverflow: Double
        /// Scenario id that produced `worstExtraOverflow`, if any.
        public let worstScenarioID: String?
        /// The largest single-child width difference across the suite.
        public let worstWidthDelta: Double
    }

    public static func summary(
        for divergences: [ScenarioDivergence] = compare()
    ) -> Summary {
        let divergent = divergences.filter { !$0.isIdentical }
        let worst = divergences.max { $0.extraOverflow < $1.extraOverflow }
        let worstDelta = divergences.map(\.maxWidthDelta).max() ?? 0
        return Summary(
            total: divergences.count,
            identical: divergences.count - divergent.count,
            divergent: divergent.count,
            worstExtraOverflow: worst?.extraOverflow ?? 0,
            worstScenarioID: (worst?.extraOverflow ?? 0) > 0 ? worst?.scenario.id : nil,
            worstWidthDelta: worstDelta
        )
    }
}
