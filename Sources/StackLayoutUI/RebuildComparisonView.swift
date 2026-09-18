#if canImport(SwiftUI)
import SwiftUI
import StackLayoutCore

/// Root view: the whole scenario suite, both allocation rules, and the list of
/// inputs on which they disagree.
public struct RebuildComparisonView: View {
    private let divergences: [ScenarioDivergence]
    private let summary: DivergenceReport.Summary

    public init(scenarios: [Scenario] = ScenarioLibrary.all) {
        let compared = DivergenceReport.compare(scenarios)
        self.divergences = compared
        self.summary = DivergenceReport.summary(for: compared)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    SummaryCard(summary: summary)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section("Scenarios") {
                    ForEach(divergences) { divergence in
                        NavigationLink {
                            ScenarioDetailView(divergence: divergence)
                        } label: {
                            ScenarioRow(divergence: divergence)
                        }
                    }
                }
            }
            .navigationTitle("Rebuilt HStack")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SummaryCard: View {
    let summary: DivergenceReport.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Two rules, same code review")
                .font(.headline)
            Text("Flexibility-ordered allocation against an even split, over the same scenario suite.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Metric(value: "\(summary.total)", label: "scenarios")
                Metric(value: "\(summary.divergent)", label: "diverge", tint: .orange)
                Metric(value: String(format: "%.1fpt", summary.worstExtraOverflow), label: "worst overflow", tint: .red)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct Metric: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScenarioRow: View {
    let divergence: ScenarioDivergence

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(divergence.scenario.title)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                if divergence.isIdentical {
                    Label("same", systemImage: "equal.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: "Δ%.0fpt", divergence.maxWidthDelta))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }
            StackStrip(result: divergence.ordered,
                       divergent: divergence.divergentChildren,
                       tint: .blue)
                .frame(height: 14)
            StackStrip(result: divergence.evenSplit,
                       divergent: divergence.divergentChildren,
                       tint: .orange)
                .frame(height: 14)
        }
        .padding(.vertical, 2)
    }
}

private struct ScenarioDetailView: View {
    let divergence: ScenarioDivergence

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(divergence.scenario.rationale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LabelledStrip(title: AllocationStrategy.flexibilityOrdered.label,
                              result: divergence.ordered,
                              divergent: divergence.divergentChildren,
                              tint: .blue)
                LabelledStrip(title: AllocationStrategy.evenSplit.label,
                              result: divergence.evenSplit,
                              divergent: divergence.divergentChildren,
                              tint: .orange)

                WidthTable(divergence: divergence)
            }
            .padding(16)
        }
        .navigationTitle(divergence.scenario.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LabelledStrip: View {
    let title: String
    let result: LayoutResult
    let divergent: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text(result.overflow > 0
                     ? String(format: "overflows %.1fpt", result.overflow)
                     : "fits")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(result.overflow > 0 ? .red : .green)
            }
            StackStrip(result: result, divergent: divergent, tint: tint)
                .frame(height: 30)
        }
    }
}

/// Draws one layout result as proportional bars inside the container width,
/// with anything past the container edge marked in red.
private struct StackStrip: View {
    let result: LayoutResult
    let divergent: [String]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let span = max(result.containerWidth, result.usedWidth, 1)
            let scale = proxy.size.width / span
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: result.containerWidth * scale)

                ForEach(result.frames, id: \.name) { frame in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colour(for: frame).opacity(0.85))
                        .frame(width: max(frame.width * scale, 1))
                        .offset(x: frame.x * scale)
                }

                if result.overflow > 0 {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: result.containerWidth * scale)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func colour(for frame: Frame) -> Color {
        divergent.contains(frame.name) ? tint : Color.gray.opacity(0.55)
    }
}

private struct WidthTable: View {
    let divergence: ScenarioDivergence

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Widths").font(.caption.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("child").gridColumnAlignment(.leading)
                    Text("ordered")
                    Text("even")
                    Text("Δ")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(rows, id: \.name) { row in
                    GridRow {
                        Text(row.name).font(.caption)
                        Text(String(format: "%.1f", row.ordered)).font(.caption.monospacedDigit())
                        Text(String(format: "%.1f", row.even)).font(.caption.monospacedDigit())
                        Text(String(format: "%.1f", row.delta))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(row.delta > DivergenceReport.tolerance ? .orange : .secondary)
                    }
                }
            }
        }
    }

    private struct Row { let name: String; let ordered: Double; let even: Double; let delta: Double }

    private var rows: [Row] {
        let a = divergence.ordered.frames
        let b = divergence.evenSplit.frames
        let count = min(a.count, b.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            Row(name: a[index].name,
                ordered: a[index].width,
                even: b[index].width,
                delta: abs(a[index].width - b[index].width))
        }
    }
}
#endif
