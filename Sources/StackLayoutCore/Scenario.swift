import Foundation

/// One concrete layout question: these children, this container, this spacing.
public struct Scenario: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    /// Why this arrangement shows up in a real screen.
    public let rationale: String
    public let containerWidth: Double
    public let spacing: Double
    public let children: [LayoutChild]

    public init(
        id: String,
        title: String,
        rationale: String,
        containerWidth: Double,
        spacing: Double,
        children: [LayoutChild]
    ) {
        self.id = id
        self.title = title
        self.rationale = rationale
        self.containerWidth = containerWidth
        self.spacing = spacing
        self.children = children
    }

    public var layout: StackLayout { StackLayout(spacing: spacing) }

    public func result(using strategy: AllocationStrategy) -> LayoutResult {
        layout.frames(for: children, in: containerWidth, using: strategy)
    }
}

/// The fixed scenario suite the tests and the demo both run.
///
/// These are hand-written rather than generated so the numbers in the README,
/// the tests and the demo UI are the same numbers every time anyone clones
/// this repo.
public enum ScenarioLibrary {
    public static let all: [Scenario] = [
        Scenario(
            id: "toolbar-icon-title-spacer",
            title: "Icon + truncating title + spacer",
            rationale: "The shape of almost every navigation bar.",
            containerWidth: 320, spacing: 8,
            children: [
                .fixed(name: "Icon", width: 120),
                .text(name: "Title", minWidth: 40, idealWidth: 200),
                .flexible(name: "Spacer", minWidth: 0, maxWidth: .infinity)
            ]
        ),
        Scenario(
            id: "two-labels-equal",
            title: "Two labels, identical flexibility",
            rationale: "The case where both rules agree — and teach you nothing.",
            containerWidth: 300, spacing: 8,
            children: [
                .text(name: "Left", minWidth: 40, idealWidth: 160),
                .text(name: "Right", minWidth: 40, idealWidth: 160)
            ]
        ),
        Scenario(
            id: "avatar-name-timestamp",
            title: "Avatar, name, timestamp",
            rationale: "A chat list row: one fixed, one greedy, one small and fixed.",
            containerWidth: 360, spacing: 12,
            children: [
                .fixed(name: "Avatar", width: 44),
                .text(name: "Name", minWidth: 60, idealWidth: 240),
                .fixed(name: "Time", width: 52)
            ]
        ),
        Scenario(
            id: "three-buttons-tight",
            title: "Three fixed buttons, container too narrow",
            rationale: "Nothing can shrink, so both rules overflow — by different amounts.",
            containerWidth: 240, spacing: 8,
            children: [
                .fixed(name: "Cancel", width: 100),
                .fixed(name: "Retry", width: 90),
                .fixed(name: "Delete", width: 96)
            ]
        ),
        Scenario(
            id: "label-spacer-chevron",
            title: "Label, spacer, chevron",
            rationale: "The disclosure row. The spacer is infinitely flexible.",
            containerWidth: 375, spacing: 8,
            children: [
                .text(name: "Label", minWidth: 50, idealWidth: 180),
                .flexible(name: "Spacer", minWidth: 0, maxWidth: .infinity),
                .fixed(name: "Chevron", width: 14)
            ]
        ),
        Scenario(
            id: "two-spacers-one-badge",
            title: "Spacer, badge, spacer",
            rationale: "Centring by spacers: both infinite, so ties decide the result.",
            containerWidth: 320, spacing: 0,
            children: [
                .flexible(name: "LeadingSpace", minWidth: 0, maxWidth: .infinity),
                .fixed(name: "Badge", width: 88),
                .flexible(name: "TrailingSpace", minWidth: 0, maxWidth: .infinity)
            ]
        ),
        Scenario(
            id: "form-field-and-unit",
            title: "Text field plus unit suffix",
            rationale: "The field should absorb the slack, not split it.",
            containerWidth: 280, spacing: 6,
            children: [
                .flexible(name: "Field", minWidth: 80, maxWidth: .infinity),
                .fixed(name: "Unit", width: 36)
            ]
        ),
        Scenario(
            id: "four-chips",
            title: "Four filter chips of unequal ideal width",
            rationale: "Chips truncate at different points, so ordering matters.",
            containerWidth: 360, spacing: 8,
            children: [
                .text(name: "All", minWidth: 32, idealWidth: 48),
                .text(name: "Unread", minWidth: 48, idealWidth: 92),
                .text(name: "Flagged", minWidth: 48, idealWidth: 104),
                .text(name: "Archived", minWidth: 48, idealWidth: 116)
            ]
        ),
        Scenario(
            id: "single-fixed",
            title: "One fixed child",
            rationale: "Degenerate case. Any divergence here is a bug.",
            containerWidth: 300, spacing: 8,
            children: [.fixed(name: "Solo", width: 140)]
        ),
        Scenario(
            id: "single-flexible",
            title: "One fully flexible child",
            rationale: "Should take the whole container under either rule.",
            containerWidth: 300, spacing: 8,
            children: [.flexible(name: "Fill", minWidth: 0, maxWidth: .infinity)]
        ),
        Scenario(
            id: "empty-stack",
            title: "No children",
            rationale: "The case that crashes naive implementations.",
            containerWidth: 300, spacing: 8,
            children: []
        ),
        Scenario(
            id: "spacing-exceeds-container",
            title: "Spacing alone exceeds the container",
            rationale: "Available width must clamp at zero, never go negative.",
            containerWidth: 40, spacing: 24,
            children: [
                .text(name: "A", minWidth: 10, idealWidth: 60),
                .text(name: "B", minWidth: 10, idealWidth: 60),
                .text(name: "C", minWidth: 10, idealWidth: 60)
            ]
        ),
        Scenario(
            id: "wide-container-all-satisfied",
            title: "Container far wider than every ideal",
            rationale: "When nothing is squeezed, the rules cannot disagree.",
            containerWidth: 900, spacing: 8,
            children: [
                .text(name: "First", minWidth: 40, idealWidth: 120),
                .text(name: "Second", minWidth: 40, idealWidth: 120),
                .text(name: "Third", minWidth: 40, idealWidth: 120)
            ]
        ),
        Scenario(
            id: "price-row",
            title: "Product name, spacer, price",
            rationale: "A cart line. The price must never truncate.",
            containerWidth: 335, spacing: 8,
            children: [
                .text(name: "Product", minWidth: 60, idealWidth: 220),
                .flexible(name: "Gap", minWidth: 8, maxWidth: .infinity),
                .fixed(name: "Price", width: 68)
            ]
        ),
        Scenario(
            id: "stepper-row",
            title: "Minus, quantity, plus",
            rationale: "Three fixed controls that fit comfortably.",
            containerWidth: 200, spacing: 12,
            children: [
                .fixed(name: "Minus", width: 32),
                .fixed(name: "Quantity", width: 40),
                .fixed(name: "Plus", width: 32)
            ]
        ),
        Scenario(
            id: "tag-list-overflow",
            title: "Five tags in a 300pt row",
            rationale: "Every child wants more than its even share.",
            containerWidth: 300, spacing: 6,
            children: [
                .text(name: "swift", minWidth: 30, idealWidth: 62),
                .text(name: "ios", minWidth: 24, idealWidth: 48),
                .text(name: "layout", minWidth: 34, idealWidth: 72),
                .text(name: "agents", minWidth: 34, idealWidth: 76),
                .text(name: "review", minWidth: 34, idealWidth: 74)
            ]
        ),
        Scenario(
            id: "icon-pair-and-title",
            title: "Two icons flanking a title",
            rationale: "Fixed, flexible, fixed — the modal header.",
            containerWidth: 320, spacing: 16,
            children: [
                .fixed(name: "Back", width: 24),
                .text(name: "Heading", minWidth: 80, idealWidth: 260),
                .fixed(name: "Close", width: 24)
            ]
        ),
        Scenario(
            id: "min-width-floor-bites",
            title: "Minimum widths larger than the even share",
            rationale: "Each child refuses its share, so the leftover has to go somewhere.",
            containerWidth: 260, spacing: 8,
            children: [
                .flexible(name: "Alpha", minWidth: 110, maxWidth: 200),
                .flexible(name: "Beta", minWidth: 110, maxWidth: 200)
            ]
        ),
        Scenario(
            id: "one-greedy-two-rigid",
            title: "One greedy child between two rigid ones",
            rationale: "The classic case for allocating the rigid children first.",
            containerWidth: 390, spacing: 10,
            children: [
                .fixed(name: "LeftRail", width: 130),
                .flexible(name: "Canvas", minWidth: 40, maxWidth: .infinity),
                .fixed(name: "RightRail", width: 130)
            ]
        ),
        Scenario(
            id: "zero-spacing-dense",
            title: "Dense row with zero spacing",
            rationale: "Spacing is not what makes the rules differ.",
            containerWidth: 320, spacing: 0,
            children: [
                .fixed(name: "Seg1", width: 90),
                .text(name: "Seg2", minWidth: 50, idealWidth: 140),
                .text(name: "Seg3", minWidth: 50, idealWidth: 140)
            ]
        ),
        Scenario(
            id: "capped-flexible-pair",
            title: "Two flexible children with different caps",
            rationale: "One saturates early and releases width to the other.",
            containerWidth: 420, spacing: 8,
            children: [
                .flexible(name: "Narrow", minWidth: 20, maxWidth: 120),
                .flexible(name: "Wide", minWidth: 20, maxWidth: 500)
            ]
        ),
        Scenario(
            id: "badge-then-long-text",
            title: "Small badge then a long headline",
            rationale: "The badge is 10% of the row but takes a third of the even split.",
            containerWidth: 330, spacing: 8,
            children: [
                .fixed(name: "New", width: 38),
                .text(name: "Headline", minWidth: 80, idealWidth: 300),
                .fixed(name: "Dot", width: 10)
            ]
        ),
        Scenario(
            id: "six-mixed",
            title: "Six mixed children",
            rationale: "Enough children that the ordering is not obvious by eye.",
            containerWidth: 414, spacing: 6,
            children: [
                .fixed(name: "A", width: 28),
                .text(name: "B", minWidth: 30, idealWidth: 90),
                .flexible(name: "C", minWidth: 10, maxWidth: .infinity),
                .fixed(name: "D", width: 44),
                .text(name: "E", minWidth: 30, idealWidth: 110),
                .fixed(name: "F", width: 20)
            ]
        ),
        Scenario(
            id: "exact-fit",
            title: "Children whose ideals exactly fill the container",
            rationale: "The boundary between fitting and squeezing.",
            containerWidth: 316, spacing: 8,
            children: [
                .text(name: "One", minWidth: 40, idealWidth: 100),
                .text(name: "Two", minWidth: 40, idealWidth: 100),
                .text(name: "Three", minWidth: 40, idealWidth: 100)
            ]
        )
    ]
}
