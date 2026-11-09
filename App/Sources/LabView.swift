import SwiftUI

/// 実験：進行中と終わった実験の一覧。新しい実験はここから。
/// iPhone Duo の内側の画面では、左に一覧、右に選んだ実験（NavigationSplitView。閉じると 1 つのスタックになる）。
struct LabView: View {
    @Environment(ExperimentStore.self) private var store
    @Binding var selection: UUID?
    let onNew: () -> Void
    let onRecord: (CheckInRequest) -> Void
    let onOpenDeck: ([DeckCard]) -> Void

    var body: some View {
        let now = Date.now
        let active = store.active(now: now)
        let finished = store.finished(now: now)
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Button(action: onNew) {
                        Label("新しい実験", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                Section {
                    if active.isEmpty {
                        Text("進行中の実験はありません。上のボタンから始めましょう。")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(active) { experiment in
                        ExperimentRow(experiment: experiment, now: now, calendar: store.calendar)
                            .tag(experiment.id)
                    }
                } header: {
                    SectionTitle(text: "進行中")
                }
                Section {
                    if finished.isEmpty {
                        Text("終わった実験はまだありません。")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(finished) { experiment in
                        ExperimentRow(experiment: experiment, now: now, calendar: store.calendar)
                            .tag(experiment.id)
                    }
                } header: {
                    SectionTitle(text: "終わった実験")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("実験")
        } detail: {
            if let id = selection, let experiment = store.experiment(id: id) {
                if experiment.isFinished(on: now, calendar: store.calendar) {
                    if CardRules.card(for: experiment) != nil {
                        CardDetailView(experimentID: id)
                    } else {
                        UnfinishedResultView(experiment: experiment) { selection = nil }
                    }
                } else {
                    ExperimentProgressView(experimentID: id, onRecord: onRecord, onOpenDeck: onOpenDeck) {
                        selection = nil
                    }
                }
            } else {
                ContentUnavailableView("実験を選んでください", systemImage: "testtube.2", description: Text("左の一覧から選ぶと、ここに中身が出ます。"))
                    .background(Palette.ground.ignoresSafeArea())
            }
        }
    }
}

struct ExperimentRow: View {
    let experiment: Experiment
    let now: Date
    let calendar: Calendar

    var body: some View {
        let finished = experiment.isFinished(on: now, calendar: calendar)
        let card = finished ? CardRules.card(for: experiment) : nil
        HStack(spacing: Space.m) {
            Image(systemName: TemplateLibrary.symbol(for: experiment))
                .font(.body.weight(.light))
                .foregroundStyle(card.map { Palette.swatch(for: $0.kind).deep } ?? Palette.sky.deep)
                .frame(width: 36, height: 36)
                .background(Circle().fill(card.map { Palette.swatch(for: $0.kind).soft } ?? Palette.sky.soft))
            VStack(alignment: .leading, spacing: 2) {
                Text(experiment.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                if let card {
                    HStack(spacing: Space.s) {
                        TagText(text: card.kind.title, color: Palette.swatch(for: card.kind).deep)
                        StarRow(stars: card.stars, color: Palette.swatch(for: card.kind).deep, size: 9)
                    }
                } else if finished {
                    TagText(text: experiment.endedEarly ? "途中で終えた（記録が足りない）" : "記録が足りず、結果なし")
                } else {
                    let today = experiment.today(on: now, calendar: calendar)
                    TagText(text: "\((today ?? experiment.duration - 1) + 1) / \(experiment.duration) 日目 · 記録 \(experiment.checkIns.count) 日")
                }
            }
            Spacer(minLength: 0)
            if experiment.isSample {
                TagText(text: "見本")
            }
        }
        .padding(.vertical, 2)
    }
}

/// 進行中の実験の中身（結果は最後の日まで伏せる）
struct ExperimentProgressView: View {
    let experimentID: UUID
    let onRecord: (CheckInRequest) -> Void
    let onOpenDeck: ([DeckCard]) -> Void
    let onDeleted: () -> Void
    @Environment(ExperimentStore.self) private var store
    @State private var confirmEnd = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            if let experiment = store.experiment(id: experimentID) {
                let now = Date.now
                let today = experiment.today(on: now, calendar: store.calendar)
                let result = Analyzer.result(for: experiment)
                let pending = experiment.pendingDays(on: now, calendar: store.calendar)
                let deck = MorningDeck.cards(experiments: [experiment], now: now, calendar: store.calendar)
                VStack(alignment: .leading, spacing: Space.l) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        TagText(text: TemplateLibrary.template(id: experiment.templateID)?.category.title ?? "じぶんの型")
                        Text(experiment.title)
                            .font(Typo.title(.title2))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("やる日：\(experiment.action)")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                        Text("\(experiment.nextMorning ? "翌朝" : "毎晩")聞くこと：\(experiment.question)")
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkSoft)
                        if let prediction = experiment.prediction {
                            Label("始める前の予想：\(prediction.title)", systemImage: prediction.symbol)
                                .font(.caption)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionTitle(text: "集まった証拠", detail: "\(experiment.checkIns.count) / \(experiment.duration) 日")
                            DayDots(experiment: experiment, today: today, size: 18)
                            HStack(spacing: Space.l) {
                                ArmPill(arm: .doIt)
                                ArmPill(arm: .rest)
                                Spacer()
                            }
                            Text(DetailText.status(experiment: experiment, finished: false, today: today, result: result, now: now, calendar: store.calendar))
                                .font(.footnote)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !deck.isEmpty {
                        Button { onOpenDeck(deck) } label: {
                            Label("けさのカードをめくる", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    ForEach(pending.prefix(4), id: \.self) { day in
                        Button {
                            onRecord(CheckInRequest(experimentID: experiment.id, day: day))
                        } label: {
                            Label(DetailText.recordLabel(experiment, day: day, today: today), systemImage: "pencil.line")
                        }
                        .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                    }
                    if let template = TemplateLibrary.template(id: experiment.templateID) {
                        Panel {
                            VStack(alignment: .leading, spacing: Space.s) {
                                SectionTitle(text: "続けるコツ")
                                Label(template.tip, systemImage: "lightbulb")
                                    .font(.footnote).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Label(template.pitfall, systemImage: "exclamationmark.triangle")
                                    .font(.footnote).foregroundStyle(Palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    HStack(spacing: Space.m) {
                        Button { confirmEnd = true } label: { Label("途中で終える", systemImage: "flag.checkered") }
                            .buttonStyle(QuietButtonStyle())
                        Button(role: .destructive) { confirmDelete = true } label: { Label("消す", systemImage: "trash") }
                            .buttonStyle(QuietButtonStyle(color: Palette.inkSoft))
                    }
                }
                .padding(Space.l)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("実験")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("ここまでの記録で結果を出しますか？", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("途中で終える") { store.endEarly(id: experimentID) }
        } message: {
            Text("やる日・やすむ日がそれぞれ \(Analyzer.minimumPerArm) 日以上あれば、カードになります。")
        }
        .confirmationDialog("この実験を消しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("消す", role: .destructive) {
                store.delete(id: experimentID)
                onDeleted()
            }
        }
    }
}

/// 終わったが、記録が足りずカードにならなかった実験
struct UnfinishedResultView: View {
    let experiment: Experiment
    let onDeleted: () -> Void
    @Environment(ExperimentStore.self) private var store

    var body: some View {
        let result = Analyzer.result(for: experiment)
        let left = ResultText.remaining(result)
        ScrollView {
            VStack(spacing: Space.l) {
                CardBack(width: 200, label: "結果なし", caption: experiment.title)
                    .opacity(0.7)
                Text("やる日・やすむ日をそれぞれ \(Analyzer.minimumPerArm) 日以上くらべると、カードになります（足りなかったのは やる日 \(left.doDays) 日・やすむ日 \(left.restDays) 日）。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("同じ実験をきょうから") { _ = store.restart(id: experiment.id) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("消す", role: .destructive) {
                    store.delete(id: experiment.id)
                    onDeleted()
                }
                .buttonStyle(QuietButtonStyle(color: Palette.inkSoft))
            }
            .padding(Space.xl)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
    }
}

/// 詳細の文（テストできるように画面から分ける）
enum DetailText {
    static func status(experiment: Experiment, finished: Bool, today: Int?, result: ExperimentResult, now: Date, calendar: Calendar) -> String {
        if experiment.endedEarly {
            return "途中で終えた実験です。ここまでの \(experiment.checkIns.count) 日分で結果を出しています。もう一度始めると、くらべる日が増えて結果が確かになります。"
        }
        if finished {
            return "実験は終わりました。結果はカードになって図鑑に入ります。"
        }
        let pending = experiment.pendingDays(on: now, calendar: calendar)
        let missing = pending.filter { $0 != today }
        if !missing.isEmpty {
            return "記録が抜けている日が \(missing.count) 日あります。思い出せる日はつけましょう。空けたままでも結果は出ます。"
        }
        let left = ResultText.remaining(result)
        if result.verdict == .notEnough {
            return "あと やる日 \(left.doDays) 日・やすむ日 \(left.restDays) 日の記録で、結果を出せる量になります。結果は最後の日まで伏せておきます。"
        }
        let days = MorningDeck.daysUntilVerdict(experiment, today: today ?? 0)
        return "結果を出せる量の証拠が集まりました。結果発表まで あと \(days) 日。途中で見ないのは、偶然の波に振り回されないためです。"
    }

    static func recordLabel(_ experiment: Experiment, day: Int, today: Int?) -> String {
        if experiment.nextMorning, let today, day == today - 1 { return "けさの記録をする" }
        if day == today { return "今日の分を記録する" }
        return "\(day + 1) 日目の分を記録する"
    }
}
