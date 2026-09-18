import SwiftUI
import StackLayoutUI

/// Runs the rebuilt stack layout against its scenario suite and shows, for
/// every scenario, what the flexibility-ordered rule and the even split each
/// produce — and where they disagree.
@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RebuildComparisonView()
        }
    }
}
