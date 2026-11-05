import SwiftUI

@main
struct SelfLabApp: App {
    @State private var store: ExperimentStore
    @AppStorage("appearance") private var appearance = 0
    private let designer: any ExperimentDesigner = OnDeviceDesigner()

    init() {
        // スクリーンショットの「実験なし」の場面は、見本のない別の保存先で開く
        if ScreenshotScene.current == .empty {
            _store = State(initialValue: ExperimentStore(key: "experiments.empty", seedSamples: false))
        } else {
            _store = State(initialValue: ExperimentStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(designer: designer)
                .environment(store)
                .preferredColorScheme(Appearance.scheme(appearance))
        }
    }
}
