import SwiftUI

/// ホーム（実験ノート）。左に今日のくじ・進行中のページ・ノートの棚、右（または次の画面）に実験の中身。
/// iPhone Duo の内側の画面では 2 列に並び、閉じると 1 列に重なる（NavigationSplitView。
/// Apple Tech Talk「Prepare your app for iPhone Duo」：列は閉じると 1 つのスタックになる）。
struct ContentView: View {
    @Environment(ExperimentStore.self) private var store
    let designer: any ExperimentDesigner

    @State private var selection: UUID?
    @State private var checkIn: CheckInRequest?
    @State private var newRequest: NewExperimentSeed?
    @State private var showingSettings = false
    @State private var revealCount = 0
    @State private var recordCount = 0
    @State private var handledScene = false
    @State private var openShare = false
    @State private var scrollToChance = false
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        let now = Date.now
        let active = store.active(now: now)
        let finished = store.finished(now: now)
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    GreetingHeader(
                        date: now,
                        streak: store.streak(now: now),
                        recordedDays: store.recordedDayCount,
                        proven: store.provenHabits(now: now).count
                    )
                }
                .clearRow()

                Section {
                    ForEach(active) { experiment in
                        TodayPage(
                            experiment: experiment,
                            now: now,
                            calendar: store.calendar,
                            onDraw: { day in
                                store.reveal(id: experiment.id, day: day)
                                revealCount += 1
                            },
                            onRecord: { day in checkIn = CheckInRequest(experimentID: experiment.id, day: day) },
                            onOpen: { selection = experiment.id }
                        )
                    }
                    if active.isEmpty {
                        EmptyNotebook { newRequest = NewExperimentSeed() }
                    }
                } header: {
                    SectionTitle(text: "今日のくじ", symbol: "dice")
                }
                .clearRow()

                Section {
                    Shelf(experiments: finished) { selection = $0 }
                } header: {
                    SectionTitle(text: "実験ノートの棚", symbol: "books.vertical")
                }
                .clearRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.desk.ignoresSafeArea())
            .navigationTitle("じぶん実験室")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newRequest = NewExperimentSeed()
                    } label: {
                        Label("実験を作る", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let id = selection, store.experiment(id: id) != nil {
                ExperimentDetailView(experimentID: id, openShare: $openShare, scrollToChance: $scrollToChance) { day in
                    checkIn = CheckInRequest(experimentID: id, day: day)
                } onDeleted: {
                    selection = nil
                } onNext: {
                    newRequest = NewExperimentSeed()
                } onRestarted: { newID in
                    selection = newID
                }
            } else {
                DetailPlaceholder()
            }
        }
        .tint(Palette.peach.deep)
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
            NewExperimentView(designer: designer, seed: request) { draft, duration in
                store.start(draft, duration: duration)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView { onboarded = true }
        }
        .haptic(.selection, trigger: revealCount)
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
        switch ScreenshotScene.current {
        case .detail:
            selection = store.finished(now: now).first { !$0.endedEarly }?.id
        case .chance:
            selection = store.finished(now: now).first { !$0.endedEarly }?.id
            scrollToChance = true
        case .share:
            selection = store.finished(now: now).first { !$0.endedEarly }?.id
            openShare = true
        case .ended:
            selection = store.finished(now: now).first { $0.endedEarly }?.id
        case .checkin:
            if let experiment = store.active(now: now).first, let today = experiment.today(on: now, calendar: store.calendar) {
                store.reveal(id: experiment.id, day: today)
                checkIn = CheckInRequest(experimentID: experiment.id, day: today)
            }
        case .reveal:
            if let experiment = store.active(now: now).first, let today = experiment.today(on: now, calendar: store.calendar) {
                store.reveal(id: experiment.id, day: today)
            }
        case .compose:
            let worry = "午後になると眠くて、仕事に集中できない"
            newRequest = NewExperimentSeed(worry: worry, suggestions: TemplateLibrary.suggestions(for: worry))
        case .catalog:
            newRequest = NewExperimentSeed(category: .sleep)
        case .settings:
            showingSettings = true
        case .launch, .home, .onboarding, .empty, nil:
            break
        }
    }
}

extension View {
    func clearRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: Space.s, leading: Space.l, bottom: Space.s, trailing: Space.l))
            .listRowSeparator(.hidden)
    }
}

/// CI のスクリーンショットで開く画面（起動引数 -screenshotScene は UserDefaults の引数ドメインに入る）
enum ScreenshotScene: String {
    case launch, home, onboarding, reveal, checkin, detail, chance, share, ended, compose, catalog, settings, empty

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }
}

struct CheckInRequest: Identifiable {
    let id = UUID()
    let experimentID: UUID
    let day: Int
}

/// 実験を作る画面を、気になること・案・分類を入れた状態で開く
struct NewExperimentSeed: Identifiable {
    let id = UUID()
    var worry = ""
    var suggestions: [ExperimentDraft] = []
    var category: TemplateCategory?
}

/// 見出し（セリフ・字間）
struct SectionTitle: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: symbol)
                .foregroundStyle(Palette.sky.deep)
            Text(text)
                .font(Typo.title(.headline))
                .kerning(0.6)
                .foregroundStyle(Palette.ink)
        }
        .textCase(nil)
        .padding(.top, Space.s)
    }
}

/// あいさつ（途切れても責めない）
enum Greeting {
    static func text(streak: Int, recordedDays: Int) -> String {
        if recordedDays == 0 { return "ようこそ。気になる習慣を 1 つ、くじで確かめてみましょう。" }
        if streak >= 2 { return "\(streak) 日続けて記録しています。今日もくじからどうぞ。" }
        if streak == 1 { return "きのうも記録しました。今日のくじを引きましょう。" }
        return "おかえりなさい。これまで \(recordedDays) 日分の記録があります。今日から続きを。"
    }
}

/// 日付スタンプ
struct DateStamp: View {
    let date: Date

    var body: some View {
        Text(date.formatted(.dateTime.month().day().weekday(.abbreviated)))
            .font(.system(.subheadline, design: .serif).weight(.regular).monospacedDigit())
            .kerning(0.6)
            .foregroundStyle(Palette.inkSoft)
    }
}

struct GreetingHeader: View {
    let date: Date
    let streak: Int
    let recordedDays: Int
    let proven: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            DateStamp(date: date)
            Text(Greeting.text(streak: streak, recordedDays: recordedDays))
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: Space.xl) {
                stat(streak, unit: "日", label: "続けて記録", color: Palette.ink)
                stat(recordedDays, unit: "日", label: "記録した日", color: Palette.ink)
                stat(proven, unit: "個", label: "効くこと", color: Palette.peach.deep)
            }
        }
        .padding(.vertical, Space.s)
    }

    private func stat(_ value: Int, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(Typo.number(.largeTitle))
                    .kerning(-3)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit).font(.caption).foregroundStyle(Palette.inkSoft)
            }
            TagText(text: label)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 進行中の実験の、今日のページ（くじ・記録・小さな記録表）
struct TodayPage: View {
    let experiment: Experiment
    let now: Date
    let calendar: Calendar
    let onDraw: (Int) -> Void
    let onRecord: (Int) -> Void
    let onOpen: () -> Void

    @State private var drawRequest = 0
    @AppStorage("drawnOnce") private var drawnOnce = false

    var body: some View {
        let today = experiment.today(on: now, calendar: calendar)
        let pending = experiment.pendingDays(on: now, calendar: calendar)
        let morningDay: Int? = experiment.nextMorning
            ? pending.first(where: { day in today.map { day == $0 - 1 } ?? (day == experiment.duration - 1) })
            : nil
        let missing = pending.first { $0 != today && $0 != morningDay }
        NotebookPage(tilt: -0.5, showsClip: true, grid: true) {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack(alignment: .top, spacing: Space.m) {
                    LabelSticker(text: experiment.title, color: Palette.sky.accent)
                    Spacer(minLength: 0)
                    Button(action: onOpen) {
                        Image(systemName: "book.pages")
                            .accessibilityLabel("ノートを開く")
                    }
                    .buttonStyle(PencilButtonStyle())
                }
                HStack(spacing: Space.s) {
                    if let today {
                        TagText(text: "\(today + 1) 日目 / \(experiment.duration) 日", color: Palette.ink)
                    } else {
                        TagText(text: "最後の朝の記録", color: Palette.ink)
                    }
                    if experiment.isSample { TagText(text: "見本") }
                }

                if let morningDay {
                    MorningRecordRow(experiment: experiment, day: morningDay) { onRecord(morningDay) }
                }

                if let today, let arm = experiment.arm(day: today) {
                    let revealed = experiment.isRevealed(day: today)
                    HStack(alignment: .bottom, spacing: Space.l) {
                        LotteryBox(arm: arm, revealed: revealed, drawRequest: drawRequest, width: 84) {
                            drawnOnce = true
                            onDraw(today)
                        }
                        if revealed {
                            ResultSlip(experiment: experiment, arm: arm, day: today) { onRecord(today) }
                                .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: Space.s) {
                                if !drawnOnce {
                                    CoachBubble(text: "筒を押してみて")
                                }
                                Text("今日はどっち？")
                                    .font(Typo.title(.title3))
                                    .foregroundStyle(Palette.ink)
                                Text("やる日とやすむ日は半分ずつ。順番はくじで決まり、当日まで秘密です。")
                                    .font(.footnote)
                                    .foregroundStyle(Palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, Space.l)
                        }
                    }
                    if !revealed {
                        Button {
                            drawRequest += 1
                        } label: {
                            Label("筒を振って、くじを引く", systemImage: "hand.tap")
                        }
                        .buttonStyle(StampButtonStyle(swatch: Palette.stone))
                    }
                }

                RecordTable(experiment: experiment, today: today, compact: true)
                    .frame(maxWidth: 230)

                if let missing {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("\(missing + 1) 日目の記録が抜けています。思い出せるなら今つけましょう。分からなければ空けたままで大丈夫（比べるのから外れるだけです）。")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            onRecord(missing)
                        } label: {
                            Label("\(missing + 1) 日目を記録する", systemImage: "pencil")
                        }
                        .buttonStyle(PencilButtonStyle(color: Palette.peach.deep))
                    }
                    .padding(Space.m)
                    .background(Palette.mist.soft)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                }
            }
        }
        .padding(.top, Space.m)
    }
}

/// くじの結果の紙片
struct ResultSlip: View {
    let experiment: Experiment
    let arm: Arm
    let day: Int
    let onRecord: () -> Void

    var body: some View {
        let swatch = Palette.swatch(for: arm)
        VStack(alignment: .leading, spacing: Space.s) {
            TagText(text: "今日のくじ")
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("今日は").font(Typo.title(.subheadline)).foregroundStyle(Palette.ink)
                Image(systemName: arm == .doIt ? "sun.min" : "moon")
                    .foregroundStyle(swatch.deep)
                Text(arm.title)
                    .font(Typo.title(.title2))
                    .kerning(-0.5)
                    .foregroundStyle(swatch.deep)
                    .lineLimit(1)
                    .fixedSize()
            }
            Text(arm == .doIt ? experiment.action : "きょうはお休み。いつもどおりに過ごします。")
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("実験メモ：\(LabNotes.note(seed: experiment.seed, day: day))")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if experiment.nextMorning {
                Label("明日の朝に記録します", systemImage: "sunrise")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            } else if let checkIn = experiment.checkIn(day: day) {
                HStack {
                    Label("記録済み \(checkIn.rating) / 5", systemImage: "checkmark.seal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(swatch.deep)
                    Spacer(minLength: 0)
                    Button("直す", action: onRecord)
                        .buttonStyle(PencilButtonStyle())
                }
            } else {
                Button(action: onRecord) {
                    Label("夜に記録する", systemImage: "moon.stars")
                }
                .buttonStyle(StampButtonStyle(swatch: swatch))
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(swatch.paper)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(swatch.accent, lineWidth: 0.8))
        .liftedShadow()
    }
}

/// 翌朝に記録する実験の、けさの記録
struct MorningRecordRow: View {
    let experiment: Experiment
    let day: Int
    let onRecord: () -> Void

    var body: some View {
        let arm = experiment.arm(day: day) ?? .doIt
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: "sunrise").foregroundStyle(Palette.peach.deep)
                Text("けさの記録").font(Typo.title(.subheadline))
                TagText(text: "きのうは\(arm.title)", color: Palette.swatch(for: arm).deep)
            }
            Text(experiment.question).font(.headline).foregroundStyle(Palette.ink)
            Button(action: onRecord) {
                Label("記録する", systemImage: "pencil")
            }
            .buttonStyle(StampButtonStyle(swatch: Palette.swatch(for: arm)))
        }
        .padding(Space.m)
        .background(Palette.peach.paper)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.peach.accent, lineWidth: 0.8))
    }
}

/// 進行中の実験がないとき
struct EmptyNotebook: View {
    let onNew: () -> Void

    var body: some View {
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                PageTitle(text: "新しい実験")
                Text("いまは進行中の実験がありません。気になることを 1 つ書くか、42 の型から選ぶと、今日からくじで確かめられます。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onNew) {
                    Label("実験を作る", systemImage: "plus")
                }
                .buttonStyle(StampButtonStyle())
            }
        }
        .padding(.top, Space.m)
    }
}

/// 実験ノートの棚（終わった実験の背表紙）
struct Shelf: View {
    let experiments: [Experiment]
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if experiments.isEmpty {
                Text("終わった実験は、ここにノートの背表紙として並びます。最初の 1 冊は、実験を始めて 8〜14 日後です。")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, Space.l)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: Space.m) {
                        ForEach(Array(experiments.enumerated()), id: \.element.id) { index, experiment in
                            Button {
                                onOpen(experiment.id)
                            } label: {
                                NotebookSpine(experiment: experiment, verdict: Analyzer.result(for: experiment).verdict, index: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Space.s)
                    .padding(.top, Space.l)
                }
            }
            // 棚板
            Rectangle()
                .fill(Palette.stone.decor)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }
}

/// 右の列に何も選ばれていないとき
struct DetailPlaceholder: View {
    var body: some View {
        ZStack {
            Palette.desk.ignoresSafeArea()
            NotebookPage {
                VStack(alignment: .leading, spacing: Space.m) {
                    PageTitle(text: "ノートを選んでください")
                    Text("左の今日のページか、棚の背表紙を押すと、記録表と、やる日・やすむ日をくらべた結果がここに開きます。")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                }
            }
            .frame(maxWidth: 520)
            .padding(Space.xl)
        }
    }
}

/// 初めて触る所への案内（吹き出し。左を指す）
struct CoachBubble: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            Triangle()
                .fill(Palette.ink)
                .frame(width: 8, height: 12)
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.paper)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xs + 2)
                .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.ink))
        }
        .liftedShadow()
        .opacity(pulse ? 0.75 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel("案内：\(text)")
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// くじの紙片の「実験メモ」（小さな驚き。種と日で決まる）
enum LabNotes {
    static let all: [String] = [
        "記録は、続けた日より正直な日のほうが役に立つ。",
        "やすむ日も、立派な実験の一部です。",
        "くじは公平。あなたの思い込みからも、気分からも。",
        "1 日の点数は気にしすぎない。くらべるのは 2 つの平均です。",
        "迷ったら、真ん中の 3 をつけていい。",
        "科学者もまず、小さな問いから始めました。",
        "うまくいかなかった日も、データです。",
        "同じ質問を同じ時間に聞くと、答えがそろいます。",
        "効かないと分かるのも、立派な結果です。",
        "今日の自分を、きのうの自分とくらべる実験です。",
        "記録の時刻をそろえると、くらべやすくなります。",
        "メモは一言で十分。あとで読むと発見があります。",
        "やる日は、いつもよりほんの少しだけ丁寧に。",
        "やすむ日は「いつもどおり」がいちばんの仕事。",
        "結果の前に、手を止めずにもう 1 日。",
        "偶然を見分けるには、日数が味方です。",
        "ハンコは最後の日のお楽しみ。",
        "記録表のマスが、少しずつ色づいていきます。",
        "実験ノートの棚は、あなたの取扱説明書になります。",
        "思いつきを確かめる人は、意外と少ない。",
        "小さな差でも、続ければ見えてきます。",
        "「なんとなく」を数字にすると、人にも話しやすくなります。",
        "今日のくじは、今日だけのもの。",
        "実験の途中で条件を変えないのがコツです。",
        "朝と夜で気分は変わる。だから同じ時間に聞きます。",
        "やる日にできなかったら、正直に「できなかった」で。",
        "1 つの実験に 1 つの問い。欲張らないのがコツ。",
        "ノートの余白は、次の実験のアイデア置き場。",
        "続けた日数より、確かめた数を誇りに。",
        "今日の記録が、何日かあとの答えになります。",
    ]

    static func note(seed: UInt64, day: Int) -> String {
        var rng = SplitMix64(state: seed &+ UInt64(max(day, 0)) &* 0x9E37_79B9)
        return all[Int(rng.next() % UInt64(all.count))]
    }
}
