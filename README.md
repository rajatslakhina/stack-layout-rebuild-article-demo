# StackLayoutRebuild

A from-scratch reimplementation of SwiftUI's horizontal stack allocation rule, sitting next to
the version of that rule most people would write — and a 24-scenario suite that says exactly
where the two disagree.

The point is not the layout engine. The point is what the exercise produces: **a list of the
specific inputs on which choosing wrong is invisible.** You cannot review code against a rule
you have not rebuilt.

Article: *"I Rebuilt HStack in 159 Lines. 14 of 24 Layouts Disagreed With the Version I Would Have
Approved."* — link added here once it publishes.

---

## The result

Run `swift test` and the suite reports:

| | |
|---|---|
| Scenarios | 24 |
| Frames identical under both rules | 10 |
| **Frames that differ** | **14** |
| Divergences that overflow the container | 2 |
| **Divergences that render clean and wrong** | **12** |
| Worst single-child width difference | **161.3pt** |
| Worst overflow the even split introduces | 18.7pt |

The last three rows are the whole argument. Only 2 of the 14 disagreements produce an overflow —
something an automated check, a snapshot diff, or a human eye can catch. The other 12 lay out
inside the container, look completely normal, and are wrong by up to 161 points.

(The even split overflows in 4 scenarios overall, but in 2 of those the ordered rule overflows
too, because the minimum widths genuinely do not fit. Those 2 are a limit, not a bug, and
`testTheEvenSplitOverflowsFourScenariosAndTheOrderedRuleTwo` pins both counts.)

## The two rules

```swift
// The rule this package rebuilds: size the least flexible child first,
// re-dividing what is left after every child answers.
let order = children.indices.sorted { lhs, rhs in
    let left = children[lhs].flexibility
    let right = children[rhs].flexibility
    if left == right { return lhs < rhs }   // ties keep declaration order
    return left < right
}

var remaining = available
var unsized = children.count
for index in order {
    guard unsized > 0 else { break }
    let proposal = remaining / Double(unsized)
    let width = children[index].width(for: .fixed(proposal))
    widths[index] = width
    remaining = Swift.max(0, remaining - width)
    unsized -= 1
}
```

```swift
// The rule that reads correct in review: divide evenly, propose the
// same share to everyone, in declaration order.
let share = available / Double(children.count)
for index in children.indices {
    widths[index] = children[index].width(for: .fixed(share))
}
```

Flexibility is the span between what a child reports for a zero proposal and what it reports
for an unbounded one. A fixed icon has a flexibility of `0`. A `Spacer` has `.infinity`. A
truncating label sits in between — and that is where the interesting cases live.

## The scenario that makes it concrete

A 320pt row: a 120pt icon, a title that truncates between 40 and 200pt, and a spacer.

```
flexibility-ordered   Icon 120.0   Title  92.0   Spacer  92.0   →  fits 320.0 exactly
even split            Icon 120.0   Title 101.3   Spacer 101.3   →  overflows by 18.7pt
```

The even split proposes 101.3pt to all three. The icon refuses and takes 120 anyway. Nobody
gives the 18.7pt back, because under that rule nobody is asked twice.

And the worst case is quieter. In `badge-then-long-text` — a 38pt badge, a headline, a 10pt dot,
in a 330pt row — the ordered rule gives the headline **266pt** and the even split gives it
**104.7pt**. No overflow. No warning. The headline simply truncates 161 points early, and the
row looks fine.

## What is in here

| Path | What it is |
|---|---|
| `Sources/StackLayoutCore/LayoutChild.swift` | The three subview shapes and their flexibility, with every number sanitised at the point of use (NaN, negatives, infinities and reversed bounds) |
| `Sources/StackLayoutCore/StackLayout.swift` | Both allocation rules, and the placement pass |
| `Sources/StackLayoutCore/Scenario.swift` | The 24 hand-written scenarios, so the numbers here, in the tests and in the demo are the same numbers |
| `Sources/StackLayoutCore/DivergenceReport.swift` | The instrument: runs both rules and reports where they part company |
| `Sources/StackLayoutUI/RebuildComparisonView.swift` | SwiftUI comparison view — both results drawn to scale, divergent children highlighted |
| `Tests/StackLayoutCoreTests/` | 27 tests. Every number quoted above is pinned by one of them |

The engine itself is 159 non-comment, non-blank lines:

```bash
cat Sources/StackLayoutCore/LayoutChild.swift Sources/StackLayoutCore/StackLayout.swift \
  | grep -vE '^\s*(//|$)' | wc -l
```

## How to run it

```bash
git clone https://github.com/rajatslakhina/stack-layout-rebuild-article-demo.git
cd stack-layout-rebuild-article-demo
swift test                      # the library and the 24-scenario report
open Demo.xcodeproj             # then pick any Simulator and Build & Run
```

No other setup. `Demo.xcodeproj` consumes the package through a local package reference to this
same repository, so there is nothing else to fetch.

## Verification status

Stated plainly, because the difference between "verified" and "looks verified" is the subject
of the article.

**Done:**

- `swift build -Xswiftc -warnings-as-errors` — clean, zero warnings (Swift 6.0.3, Linux aarch64, language mode 6)
- `swift test` — **27 of 27 passing**
- `Demo.xcodeproj/project.pbxproj` validated programmatically: braces and parens balanced, all 24 object ids defined, zero dangling references
- `Demo.xcodeproj/xcshareddata/xcschemes/Demo.xcscheme` parsed as XML
- `Demo/DemoApp.swift` and `Sources/StackLayoutUI/RebuildComparisonView.swift` both `swiftc -parse` clean

**Not done:**

- **The app was never run on a Simulator, and no screenshot of it exists.** This repository was
  produced by an unattended scheduled run whose session had no tool able to drive macOS
  applications — the only `computer`-style tools present were scoped to browser tabs. Xcode was
  never opened. `Demo/Screenshots/` is deliberately empty and says so.
- Consequently `StackLayoutUI` has been parsed and type-checked as part of a Linux build, but
  has never been seen rendering on a device. It also has no tests: the test target covers
  `StackLayoutCore` only, so every verified number above comes from the engine, not the view.
- The rebuilt rule has not been diffed against a live SwiftUI render. The comparison this repo
  makes is between the rebuild and the plausible-but-wrong even split — which is the comparison
  the argument needs, but it is not a claim about what Apple's implementation does internally.

The CI workflow in `.github/workflows/ci.yml` builds the library on Linux and macOS and builds
`Demo.xcodeproj` for a generic iOS Simulator destination, which is the closest thing to a
device check that runs without a human.

## Licence

MIT.
