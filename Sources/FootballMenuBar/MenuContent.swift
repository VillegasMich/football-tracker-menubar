import SwiftUI

/// The contents of the menu bar dropdown. Add your own items here.
struct MenuContent: View {
    var body: some View {
        Button("Refresh") {
            // TODO: hook up your action
        }
        .keyboardShortcut("r")

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
