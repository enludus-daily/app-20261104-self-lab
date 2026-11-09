import SwiftUI

enum AppTab: Hashable {
    case today, collection, lab, settings
}

/// けさの開封を開くときの中身
struct DeckPresentation: Identifiable {
    let id = UUID()
    var cards: [DeckCard]
    var initialIndex = 0
    var flipped = false
}

/// 画面の骨組み：iOS 26 の標準の TabView（Liquid Glass の浮いたタブバー）。きょう・図鑑・実験・設定。
/// iPhone Duo の内側の大きな画面では、各タブの中で 2 列に並べる（size class で切り替え。機種では決めない）。
struct ContentView: View {
    @Environment(ExperimentStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    let designer: any ExperimentDesigner

    @State private var tab: AppTab = .today
    @State private var deck: DeckPresentation?
    @State private var checkIn: CheckInRequest?
    @State private var newRequest: NewExperimentSeed?
    @State private var labSelection: UUID?
    @State private var cardSelection: UUID?
    @State private var cardPushed: UUID?
    @State private var paywall: PaywallReason?
    @State private var recordCount = 0
    @State private var handledScene = false
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("きょう", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView(
                    onOpenDeck: { deck = DeckPresentation(cards: $0) },
                    onRecord: { checkIn = $0 },
                    onNewExperiment: { newRequest = NewExperimentSeed() },
                    onShowCollection: { tab = .collection }
                )
            }
            Tab("図鑑", systemImage: "rectangle.portrait.on.rectangle.portrait", value: AppTab.collection) {
                CollectionView(selected: $cardSelection, pushed: $cardPushed) { template in
                    newRequest = NewExperimentSeed(template: template)
                }
            }
            Tab("実験", systemImage: "testtube.2", value: AppTab.lab) {
                LabView(
                    selection: $labSelection,
                    onNew: { newRequest = NewExperimentSeed() },
                    onRecord: { checkIn = $0 },
                    onOpenDeck: { deck = DeckPresentation(cards: $0) }
                )
            }
            Tab("設定", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.sky.deep)
        .fullScreenCover(item: $deck) { presentation in
            RevealView(deck: presentation.cards, initialIndex: presentation.initialIndex, initiallyFlipped: presentation.flipped)
        }
        .sheet(item: $checkIn) { request in
            if let experiment = store.experiment(id: request.experimentID) {
                CheckInSheet(experiment: experiment, day: request.day) { rating, followed, note in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if store.record(id: experiment.id, day: request.day, rating: rating, followed: followed, note: note) {
                            recordCount += 1
                        }
                    }
                }
            }
        }
        .sheet(item: $newRequest) { request in
            NewExperimentView(designer: designer, seed: request)
        }
        .sheet(item: $paywall) { reason in
            PaywallView(reason: reason)
        }
        .overlay {
            Color.clear
                .fullScreenCover(isPresented: onboardingBinding) {
                    OnboardingView { onboarded = true }
                }
        }
        .haptic(.success, trigger: recordCount)
        .onAppear(perform: openScreenshotScene)
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: {
                let scene = ScreenshotScene.current
                return scene == .onboarding || (scene == nil && !onboarded)
            },
            set: { shown in if !shown { onboarded = true } }
        )
    }

    /// CI のスクリーンショット用：起動引数 -screenshotScene <名前> で画面を開く
    private func openScreenshotScene() {
        guard !handledScene else { return }
        handledScene = true
        let now = Date.now
        let finishedCard = store.finished(now: now).first { !$0.endedEarly && $0.prediction == .works && CardRules.card(for: $0)?.kind == .proven }
        let active = store.active(now: now).first
        switch ScreenshotScene.current {
        case .reveal:
            if let active {
                let cards = MorningDeck.cards(experiments: [active], now: now, calendar: store.calendar)
                deck = DeckPresentation(cards: cards, initialIndex: max(cards.count - 1, 0), flipped: true)
            }
        case .deck:
            if let active {
                deck = DeckPresentation(cards: MorningDeck.cards(experiments: [active], now: now, calendar: store.calendar))
            }
        case .verdict:
            if let finishedCard {
                deck = DeckPresentation(cards: [.verdict(experimentID: finishedCard.id)], flipped: true)
            }
        case .collection:
            tab = .collection
        case .card:
            tab = .collection
            cardSelection = finishedCard?.id
            cardPushed = finishedCard?.id
        case .lab:
            tab = .lab
        case .detail:
            tab = .lab
            labSelection = active?.id
        case .checkin:
            if let active, let today = active.today(on: now, calendar: store.calendar) {
                store.reveal(id: active.id, day: today)
                checkIn = CheckInRequest(experimentID: active.id, day: today)
            }
        case .compose:
            newRequest = NewExperimentSeed(worry: "午後になると眠くて、仕事に集中できない")
        case .catalog:
            newRequest = NewExperimentSeed(category: .study)
        case .paywall:
            paywall = .afterCard
        case .settings:
            tab = .settings
        case .launch, .home, .onboarding, .empty, nil:
            break
        }
    }
}

/// CI のスクリーンショットで開く画面（起動引数 -screenshotScene は UserDefaults の引数ドメインに入る）
enum ScreenshotScene: String {
    case launch, home, onboarding, deck, reveal, verdict, collection, card, lab, detail, checkin, compose, catalog, paywall, settings, empty

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }
}
