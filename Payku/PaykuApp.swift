import SwiftUI

@main
struct PaykuApp: App {
    @State private var store = PaykuStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(PaykuColor.brand)
        }
    }
}
