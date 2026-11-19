import SwiftUI

@main
struct PIUApp: App {
    @StateObject private var store = PortStore()

    var body: some Scene {
        MenuBarExtra {
            PopupView()
                .environmentObject(store)
        } label: {
            Image(nsImage: MenuBarIcon.image(count: store.devPorts.count))
        }
        .menuBarExtraStyle(.window)
    }
}
