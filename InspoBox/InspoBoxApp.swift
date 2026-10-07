import SwiftUI

@main
struct InspoBoxApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra("InspoBox", systemImage: "sparkles.rectangle.stack") {
            ContentView()
                .environmentObject(store)
                .frame(width: 560, height: 720)
        }
        .menuBarExtraStyle(.window)

        Window("InspoBox", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 600)
        }
    }
}
