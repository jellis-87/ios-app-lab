import SwiftUI

/// UI tests need a host app to run against. The live session drives a different
/// app (by bundle ID), so this one only exists to satisfy that requirement.
@main
struct LiveDriverHostApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Live driver")
        }
    }
}
