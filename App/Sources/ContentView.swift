import SwiftUI

/// ホーム。左に今日のくじと実験の一覧、右（または次の画面）に実験の結果。
/// iPhone Duo の内側の画面では 2 列に並び、閉じると 1 列に重なる（NavigationSplitView。
/// Apple Tech Talk「Prepare your app for iPhone Duo」：列は閉じると 1 つのスタックになる）。
struct ContentView: View {
    @Environment(ExperimentStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let designer: any ExperimentDesigner

    @State private var selection: UUID?
    @State private var checkIn: CheckInRequest?
    @State private var showingNew = false
    @State private var newSeed: NewExperimentSeed?
    @State private var revealCount = 0
    @State private var handledScene = false

    var body: some View {
        let now = Date.now
        let active = store.active(now: now)
        let finished = store.finished(now: now)
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    SummaryHeader(streak: store.streak(now: now), recordedDays: store.recordedDayCount, proven: store.provenHabits(now: now))
                }
                .clearRow()

                Section {
                    ForEach(active) { experiment in
                        let today = experiment.today(on: now, calendar: store.calendar)
                        TodayCard(
                            experiment: experiment,
                            today: today,
                            pendingEarlier: experiment.pendingDays(on: now, calendar: store.calendar).first { $0 != today },
                            onReveal: {
                                if let today {
                                    store.reveal(id: experiment.id, day: today)
                                    revealCount += 1
                                }
                            },
                            onRecord: { day in checkIn = CheckInRequest(experimentID: experiment.id, day: day) },
                            onOpen: { selection = experiment.id }
                        )
                    }
                    if active.isEmpty {
                        StartCard { showingNew = true }
                    }
                } header: {
                    sectionHeader(active.isEmpty ? "実験" : "今日のくじ")
                }
                .clearRow()

                if !finished.isEmpty {
                    Section {
                        ForEach(finished) { experiment in
                            NavigationLink(value: experiment.id) {
                                ExperimentRow(experiment: experiment)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { store.delete(id: finished[index].id) }
                        }
                    } header: {
                        sectionHeader("結果の出た実験（\(finished.count)）")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("じぶん実験室")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Label("実験を作る", systemImage: "plus")
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: revealCount)
        } detail: {
            if let id = selection, store.experiment(id: id) != nil {
                ExperimentDetailView(experimentID: id) { day in
                    checkIn = CheckInRequest(experimentID: id, day: day)
                } onDeleted: {
                    selection = nil
                } onNext: {
                    showingNew = true
                }
            } else {
                ContentUnavailableView(
                    "実験を選んでください",
                    systemImage: "flask",
                    description: Text("左の一覧から選ぶと、日ごとの記録と、やる日・やすむ日の比べた結果が見られます。")
                )
                .background(Theme.background(scheme).ignoresSafeArea())
            }
        }
        .tint(Theme.teal)
        .sheet(item: $checkIn) { request in
            if let experiment = store.experiment(id: request.experimentID) {
                CheckInSheet(experiment: experiment, day: request.day) { rating, followed, note in
                    store.record(id: experiment.id, day: request.day, rating: rating, followed: followed, note: note)
                }
            }
        }
        .sheet(isPresented: $showingNew, onDismiss: { newSeed = nil }) {
            NewExperimentView(designer: designer, seed: newSeed) { draft, duration in
                store.start(draft, duration: duration)
            }
        }
        .onAppear(perform: openScreenshotScene)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    /// CI のスクリーンショット用：起動引数 -screenshotScene <名前> で画面を開く
    private func openScreenshotScene() {
        guard !handledScene else { return }
        handledScene = true
        let now = Date.now
        switch ScreenshotScene.current {
        case .detail:
            selection = store.finished(now: now).first?.id
        case .checkin:
            if let experiment = store.active(now: now).first, let today = experiment.today(on: now, calendar: store.calendar) {
                store.reveal(id: experiment.id, day: today)
                checkIn = CheckInRequest(experimentID: experiment.id, day: today)
            }
        case .compose:
            let worry = "午後になると眠くて、仕事に集中できない"
            newSeed = NewExperimentSeed(worry: worry, suggestions: TemplateLibrary.suggestions(for: worry))
            showingNew = true
        case .reveal:
            if let experiment = store.active(now: now).first, let today = experiment.today(on: now, calendar: store.calendar) {
                store.reveal(id: experiment.id, day: today)
            }
        case nil:
            break
        }
    }
}

private extension View {
    func clearRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
            .listRowSeparator(.hidden)
    }
}

/// CI のスクリーンショットで開く画面（起動引数 -screenshotScene は UserDefaults の引数ドメインに入る）
enum ScreenshotScene: String {
    case detail, checkin, compose, reveal

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }
}

struct CheckInRequest: Identifiable {
    let id = UUID()
    let experimentID: UUID
    let day: Int
}

/// 実験を作る画面を、気になることと案を入れた状態で開く（スクリーンショット用）
struct NewExperimentSeed {
    var worry: String
    var suggestions: [ExperimentDraft]
}
