import SwiftUI

/// きょう：けさの開封（重ねた伏せカード）→ きょうのくじ → 今夜の記録。主な操作は画面の上半分に置き、スクロールせずに見える。
/// iPhone Duo の内側の大きな画面（横が regular）では、左に開封とくじ、右に進行中の実験と図鑑の新着を並べる。
struct TodayView: View {
    @Environment(ExperimentStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    let onOpenDeck: ([DeckCard]) -> Void
    let onRecord: (CheckInRequest) -> Void
    let onNewExperiment: () -> Void
    let onShowCollection: () -> Void

    var body: some View {
        let now = Date.now
        let deck = MorningDeck.cards(experiments: store.experiments, now: now, calendar: store.calendar)
        let active = store.active(now: now)
        let cards = CardBook.cards(experiments: store.experiments, now: now, calendar: store.calendar)
        ScrollView {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.l) {
                        header(now: now, cards: cards)
                        hero(deck: deck, active: active, now: now)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: Space.l) {
                        pendingRecords(active: active, now: now)
                        progressList(active: active, now: now)
                        collectionTeaser(cards: cards)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.s)
                }
                .padding(Space.xl)
            } else {
                VStack(alignment: .leading, spacing: Space.l) {
                    header(now: now, cards: cards)
                    hero(deck: deck, active: active, now: now)
                    pendingRecords(active: active, now: now)
                    progressList(active: active, now: now)
                    collectionTeaser(cards: cards)
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xl)
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 見出し

    private func header(now: Date, cards: [HabitCard]) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(now.formatted(.dateTime.month().day().weekday(.abbreviated)))
                    .font(.system(.footnote, design: .serif).monospacedDigit())
                    .kerning(0.6)
                    .foregroundStyle(Palette.inkSoft)
                Text(Greeting.text(streak: store.streak(now: now), recordedDays: store.recordedDayCount))
                    .font(Typo.title(.title3))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.s)
            stat(store.streak(now: now), label: "連続")
            stat(cards.count, label: "カード")
        }
    }

    private func stat(_ value: Int, label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(Typo.number(.title))
                .kerning(-2)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            TagText(text: label)
        }
        .frame(minWidth: 44)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 主役

    @ViewBuilder
    private func hero(deck: [DeckCard], active: [Experiment], now: Date) -> some View {
        if !deck.isEmpty {
            let hasVerdict = Self.hasVerdict(deck)
            Panel(padding: Space.l) {
                HStack(alignment: .center, spacing: Space.l) {
                    DeckStack(count: deck.count, width: 128, caption: "\(deck.count) 枚")
                        .frame(width: 150, height: CardMetrics.height(for: 128) + 16)
                        .onTapGesture { onOpenDeck(deck) }
                    VStack(alignment: .leading, spacing: Space.s) {
                        TagText(text: hasVerdict ? "結果発表があります" : "けさの開封", color: Palette.sky.deep)
                        Text(hasVerdict ? "カードが 1 枚、届いています" : "きのうの記録と、きょうのくじ")
                            .font(Typo.title(.headline))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("1 枚ずつめくって、きょうを決めます。")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    onOpenDeck(deck)
                } label: {
                    Label("めくる", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, Space.s)
            }
        } else if active.isEmpty {
            Panel {
                VStack(alignment: .leading, spacing: Space.m) {
                    TagText(text: "進行中の実験はありません", color: Palette.sky.deep)
                    Text("気になる習慣を 1 つ、くじで確かめましょう")
                        .font(Typo.title(.headline))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(TemplateLibrary.freeCount) の型から選べます。8 日か 14 日で、結果がカードになります。")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onNewExperiment) {
                        Label("実験を始める", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        } else {
            VStack(spacing: Space.m) {
                ForEach(active) { experiment in
                    TodayLotRow(experiment: experiment, now: now, calendar: store.calendar, onRecord: onRecord)
                }
            }
        }
    }

    static func hasVerdict(_ deck: [DeckCard]) -> Bool {
        deck.contains { card in
            if case .verdict = card { return true }
            return false
        }
    }

    // MARK: - 記録・進行中・図鑑

    private func missingRecords(active: [Experiment], now: Date) -> [PendingRecord] {
        var result: [PendingRecord] = []
        for experiment in active {
            let today = experiment.today(on: now, calendar: store.calendar)
            let days = experiment.pendingDays(on: now, calendar: store.calendar).filter { $0 != today }
            for day in days.prefix(3) {
                result.append(PendingRecord(experiment: experiment, day: day, today: today))
            }
        }
        return result
    }

    @ViewBuilder
    private func pendingRecords(active: [Experiment], now: Date) -> some View {
        let missing = missingRecords(active: active, now: now)
        if !missing.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionTitle(text: "記録が抜けている日", detail: "\(missing.count) 日")
                ForEach(missing) { item in
                    Button {
                        onRecord(CheckInRequest(experimentID: item.experiment.id, day: item.day))
                    } label: {
                        HStack {
                            Text(DetailText.recordLabel(item.experiment, day: item.day, today: item.today))
                            Spacer()
                            Text(item.experiment.title).lineLimit(1).foregroundStyle(Palette.inkSoft)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func progressList(active: [Experiment], now: Date) -> some View {
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionTitle(text: "進行中", detail: "\(active.count) / \(ProGate.proActiveLimit)")
                ForEach(active) { experiment in
                    let today = experiment.today(on: now, calendar: store.calendar)
                    Panel(padding: Space.m) {
                        VStack(alignment: .leading, spacing: Space.s) {
                            HStack {
                                Image(systemName: TemplateLibrary.symbol(for: experiment))
                                    .foregroundStyle(Palette.sky.deep)
                                Text(experiment.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                Spacer()
                                TagText(text: "\((today ?? experiment.duration - 1) + 1) / \(experiment.duration) 日")
                            }
                            DayDots(experiment: experiment, today: today, size: 12)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func collectionTeaser(cards: [HabitCard]) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionTitle(text: "図鑑", detail: "\(CardBook.discovered(cards)) / \(TemplateLibrary.all.count)")
            if cards.isEmpty {
                Text("実験が終わると、結果がカードになってここに集まります。効いた習慣も、思い込みだった習慣も。")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button(action: onShowCollection) {
                    HStack(spacing: -24) {
                        ForEach(Array(cards.prefix(4).enumerated()), id: \.element.id) { offset, card in
                            CardFace(card: card, width: 92)
                                .rotationEffect(.degrees(Double(offset) * 4 - 6))
                                .softShadow()
                        }
                        Spacer(minLength: Space.xl)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.leading, Space.s)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("図鑑を開く。\(cards.count) 枚")
            }
        }
    }
}

/// きょうのくじ（めくったあと）と、今夜の記録
struct TodayLotRow: View {
    let experiment: Experiment
    let now: Date
    let calendar: Calendar
    let onRecord: (CheckInRequest) -> Void

    var body: some View {
        let today = experiment.today(on: now, calendar: calendar)
        let day = today ?? 0
        let arm = experiment.arm(day: day) ?? .doIt
        let swatch = Palette.swatch(for: arm)
        let pending = experiment.pendingDays(on: now, calendar: calendar)
        // 期間の外（翌朝に記録する実験の、最後の日の翌朝）は、残った記録だけ
        let recordDay = today.map { experiment.nextMorning ? $0 - 1 : $0 } ?? pending.first ?? -1
        let canRecord = recordDay >= 0 && pending.contains(recordDay)
        Panel {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .center, spacing: Space.m) {
                    ZStack {
                        Circle().fill(swatch.soft)
                        Image(systemName: arm == .doIt ? "sun.max" : "moon")
                            .font(.title2.weight(.light))
                            .foregroundStyle(swatch.deep)
                    }
                    .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        TagText(text: "\(day + 1) 日目 · \(experiment.title)")
                            .lineLimit(1)
                        Text(today == nil ? "最後の記録" : "きょうは\(arm.title)")
                            .font(Typo.title(.title2))
                            .foregroundStyle(Palette.ink)
                    }
                }
                Text(arm == .doIt ? "「\(experiment.action)」" : "いつもどおりに過ごす（\(experiment.action)はしない）")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if canRecord {
                    Button {
                        onRecord(CheckInRequest(experimentID: experiment.id, day: recordDay))
                    } label: {
                        Label(experiment.nextMorning ? "けさの記録をする" : "今夜の記録をする", systemImage: "pencil.line")
                    }
                    .buttonStyle(PrimaryButtonStyle(swatch: swatch))
                } else {
                    Label(experiment.nextMorning ? "あすの朝に記録します" : "記録しました。あすの朝、つぎのカード", systemImage: experiment.nextMorning ? "sunrise" : "checkmark")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }
}

/// あいさつ（途切れても責めない）
enum Greeting {
    static func text(streak: Int, recordedDays: Int) -> String {
        if recordedDays == 0 { return "ようこそ。思い込みを 1 つ、カードにしましょう。" }
        if streak >= 2 { return "\(streak) 日続けています。けさの 1 枚を。" }
        if streak == 1 { return "きのうも記録しました。けさの 1 枚を。" }
        return "おかえりなさい。きょうから続きを。"
    }
}

struct PendingRecord: Identifiable {
    let experiment: Experiment
    let day: Int
    let today: Int?

    var id: String { "\(experiment.id)-\(day)" }
}

struct CheckInRequest: Identifiable {
    let id = UUID()
    let experimentID: UUID
    let day: Int
}
