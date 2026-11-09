import SwiftUI

@main
struct SelfLabApp: App {
    @State private var store: ExperimentStore
    @State private var purchases: PurchaseStore
    @AppStorage("appearance") private var appearance = 0
    private let designer: any ExperimentDesigner = OnDeviceDesigner()

    init() {
        // スクリーンショットの「実験なし」の場面は、見本のない別の保存先で開く
        if ScreenshotScene.current == .empty {
            _store = State(initialValue: ExperimentStore(key: "experiments.empty", seedSamples: false))
        } else {
            _store = State(initialValue: ExperimentStore())
        }
        _purchases = State(initialValue: PurchaseStore.live())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(designer: designer)
                .environment(store)
                .environment(purchases)
                .preferredColorScheme(Appearance.scheme(appearance))
                .task { await purchases.load() }
        }
    }
}
