Intentionally empty.

No Simulator screenshot exists for this repository, and none is claimed anywhere in it.

This repo was produced by an unattended scheduled run. That session had no tool capable of
driving macOS applications at all — the only `computer`-style tools available were scoped to
browser tabs — so Xcode could not be opened and the Simulator could not be booted. Rather than
ship an image that was never captured, this folder is left empty and the omission is stated in
the repository README's "Verification status" section.

What *was* verified is listed there too: a zero-warning `swift build -Xswiftc -warnings-as-errors`,
23 passing tests on Swift 6.0.3, a programmatically validated `project.pbxproj`, and a
`swiftc -parse` clean bill on both SwiftUI sources.
