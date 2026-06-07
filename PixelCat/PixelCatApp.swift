import SwiftUI

@main
struct PixelCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar / accessory app: no main window. The Settings scene provides
        // an empty, unopened scene so SwiftUI's App has a valid body.
        SwiftUI.Settings {
            EmptyView()
        }
    }
}
