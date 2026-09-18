import Foundation

/// The rectangle a child ends up occupying on the horizontal axis.
public struct Frame: Sendable, Hashable {
    public let name: String
    public let x: Double
    public let width: Double

    public init(name: String, x: Double, width: Double) {
        self.name = name
        self.x = x
        self.width = width
    }

    public var maxX: Double { x + width }
}

/// The outcome of one layout pass.
public struct LayoutResult: Sendable, Hashable {
    /// Frames in the order the children were declared, not the order they
    /// were sized in.
    public let frames: [Frame]
    public let containerWidth: Double

    public init(frames: [Frame], containerWidth: Double) {
        self.frames = frames
        self.containerWidth = containerWidth
    }

    /// The right edge of the widest-reaching frame, or `0` for an empty stack.
    public var usedWidth: Double {
        frames.map(\.maxX).max() ?? 0
    }

    /// How far past the container the content runs. `0` when it fits.
    public var overflow: Double {
        Swift.max(0, usedWidth - containerWidth)
    }
}

/// Which rule the stack uses to hand out its available width.
public enum AllocationStrategy: String, Sendable, CaseIterable {
    /// Size the least flexible child first, re-dividing what is left after
    /// every child answers. This is the rule objc.io's *SwiftUI Layout
    /// Explained* series established by reimplementation, and the one this
    /// package rebuilds from scratch.
    case flexibilityOrdered

    /// Divide the available width evenly and propose the same share to every
    /// child, in declaration order. This is the implementation that reads
    /// correct in review — and is the one under test here.
    case evenSplit

    public var label: String {
        switch self {
        case .flexibilityOrdered: return "Flexibility-ordered"
        case .evenSplit: return "Even split"
        }
    }
}

/// A from-scratch horizontal stack layout.
///
/// Deliberately has no dependency on SwiftUI, UIKit or Foundation geometry:
/// the whole point of the exercise is that the allocation rule is a piece of
/// arithmetic you can hold in your head, write down, and test.
public struct StackLayout: Sendable, Hashable {
    /// Gap inserted between adjacent children. Negative and NaN values are
    /// treated as `0`.
    public let spacing: Double

    public init(spacing: Double = 8) {
        self.spacing = spacing.isNaN ? 0 : Swift.max(0, spacing)
    }

    /// Lay `children` out inside `containerWidth` using `strategy`.
    ///
    /// - Returns: one frame per child, in declaration order. An empty
    ///   children array produces an empty result rather than a crash.
    public func frames(
        for children: [LayoutChild],
        in containerWidth: Double,
        using strategy: AllocationStrategy
    ) -> LayoutResult {
        // An unbounded container is not a layout, it is a sizing question, so
        // treat it as zero rather than letting `.infinity` reach the frames.
        let container = containerWidth.isFinite ? Swift.max(0, containerWidth) : 0
        guard !children.isEmpty else {
            return LayoutResult(frames: [], containerWidth: container)
        }

        let gaps = spacing * Double(children.count - 1)
        let available = Swift.max(0, container - gaps)
        let widths = allocate(available, to: children, using: strategy)

        var frames: [Frame] = []
        frames.reserveCapacity(children.count)
        var cursor = 0.0
        for index in children.indices {
            let width = widths[index]
            frames.append(Frame(name: children[index].name, x: cursor, width: width))
            cursor += width
            if index < children.count - 1 { cursor += spacing }
        }
        return LayoutResult(frames: frames, containerWidth: container)
    }

    // MARK: - The two rules

    private func allocate(
        _ available: Double,
        to children: [LayoutChild],
        using strategy: AllocationStrategy
    ) -> [Double] {
        var widths = [Double](repeating: 0, count: children.count)

        switch strategy {
        case .evenSplit:
            let share = available / Double(children.count)
            for index in children.indices {
                widths[index] = children[index].width(for: .fixed(share))
            }

        case .flexibilityOrdered:
            // Stable sort: ties fall back to declaration order, so the result
            // never depends on the sort algorithm's internals.
            let order = children.indices.sorted { lhs, rhs in
                let left = children[lhs].flexibility
                let right = children[rhs].flexibility
                if left == right { return lhs < rhs }
                return left < right
            }

            var remaining = available
            var unsized = children.count
            for index in order {
                guard unsized > 0 else { break }
                let proposal = remaining / Double(unsized)
                let width = children[index].width(for: .fixed(proposal))
                widths[index] = width
                // A child is allowed to take more than it was offered; the
                // children sized after it simply have less to divide.
                remaining = Swift.max(0, remaining - width)
                unsized -= 1
            }
        }

        return widths
    }
}
