import Foundation

/// The width a container offers a child during a sizing pass.
///
/// This mirrors the three questions a SwiftUI stack actually asks its
/// subviews: "how small can you be", "how large can you be", and
/// "here is a concrete number, what do you do with it".
public enum ProposedWidth: Sendable, Hashable {
    /// `nil`-equivalent in SwiftUI terms: propose the smallest sensible width.
    case zero
    /// Propose an unbounded width: report the ideal/maximum.
    case infinity
    /// Propose a concrete number of points.
    case fixed(Double)
}

/// A subview modelled only by how it answers a width proposal.
///
/// Every case sanitises its own stored numbers inside ``width(for:)`` rather
/// than at construction time, because enum cases cannot run a validating
/// initialiser. Negative, NaN, infinite and reversed bounds are all repaired
/// there, so the width this type reports is always non-negative, and always
/// finite except for an unbounded proposal on a genuinely unbounded maximum.
/// The one number this type does not own is the stack's spacing; ``StackLayout``
/// sanitises that.
public enum LayoutChild: Sendable, Hashable {
    /// A view that reports the same width whatever it is proposed —
    /// an icon, a fixed-width badge, a `.frame(width:)` modifier.
    case fixed(name: String, width: Double)

    /// A view that clamps the proposal into `[minWidth, maxWidth]`.
    /// `maxWidth` may be `.infinity` for a fully flexible spacer or divider.
    case flexible(name: String, minWidth: Double, maxWidth: Double)

    /// A view that truncates: it never grows past `idealWidth` and never
    /// shrinks below `minWidth`. This is the case that makes stack layout
    /// interesting, because its flexibility is finite but non-zero.
    case text(name: String, minWidth: Double, idealWidth: Double)

    /// Display name, used for frame identity and in the demo UI.
    public var name: String {
        switch self {
        case .fixed(let name, _): return name
        case .flexible(let name, _, _): return name
        case .text(let name, _, _): return name
        }
    }

    /// The width this child reports for a given proposal.
    ///
    /// Guaranteed to return a non-negative number, and guaranteed finite for
    /// every proposal except ``ProposedWidth/infinity`` on a child whose
    /// maximum is itself unbounded.
    public func width(for proposal: ProposedWidth) -> Double {
        switch self {
        case .fixed(_, let width):
            return Self.floored(width)

        case .flexible(_, let minWidth, let maxWidth):
            let lo = Self.floored(minWidth)
            let hi = Self.ceiling(maxWidth, notBelow: lo)
            switch proposal {
            case .zero: return lo
            case .infinity: return hi
            case .fixed(let value): return Self.clamp(value, lo, hi)
            }

        case .text(_, let minWidth, let idealWidth):
            let lo = Self.floored(minWidth)
            let hi = Self.ceiling(idealWidth, notBelow: lo)
            switch proposal {
            case .zero: return lo
            case .infinity: return hi
            case .fixed(let value): return Self.clamp(value, lo, hi)
            }
        }
    }

    /// How much this child is willing to stretch: the span between the width
    /// it reports for a zero proposal and the width it reports for an
    /// unbounded one.
    ///
    /// A fixed child has a flexibility of `0`. A spacer has `.infinity`.
    /// Everything interesting sits in between.
    public var flexibility: Double {
        let lo = width(for: .zero)
        let hi = width(for: .infinity)
        guard lo.isFinite else { return 0 }
        guard hi.isFinite else { return .infinity }
        return Swift.max(0, hi - lo)
    }

    // MARK: - Sanitising

    /// Lower bounds and fixed widths must be finite: an infinite frame is not
    /// a layout, it is a bug that renders as a blank screen. NaN, `.infinity`
    /// and negatives all collapse to `0`.
    private static func floored(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.max(0, value)
    }

    /// Upper bounds are the one place `.infinity` is meaningful — that is what
    /// a `Spacer` is — so it survives here. Reversed bounds are repaired by
    /// raising the maximum to the minimum rather than trapping.
    private static func ceiling(_ value: Double, notBelow lowerBound: Double) -> Double {
        guard !value.isNaN else { return lowerBound }
        guard value.isFinite else { return .infinity }
        return Swift.max(Swift.max(0, value), lowerBound)
    }

    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        guard !value.isNaN else { return lo }
        if value < lo { return lo }
        if value > hi { return hi }
        return value
    }
}
