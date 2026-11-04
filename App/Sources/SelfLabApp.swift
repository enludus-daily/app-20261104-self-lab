import SwiftUI

@main
struct SelfLabApp: App {
    @State private var store = ExperimentStore()
    private let designer: any ExperimentDesigner = OnDeviceDesigner()

    var body: some Scene {
        WindowGroup {
            ContentView(designer: designer)
                .environment(store)
        }
    }
}
