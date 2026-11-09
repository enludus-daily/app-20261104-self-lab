import SwiftUI
import Charts

enum CardFilter: String, CaseIterable, Identifiable {
    case all, proven, myth, backfire

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "すべて"
        case .proven: "効いた"
        case .myth: "思い込み"
        case .backfire: "逆効果"
        }
    }

    var kind: CardKind? {
        switch self {
        case .all: nil
        case .proven: .proven
        case .myth: .myth
        case .backfire: .backfire
        }
    }
}

/// 図鑑：型ごとの枠に、終わった実験のカードが入る。まだの枠は点線。
/// iPhone Duo の内側の画面では、左に一覧、右に選んだカードを大きく並べる。
struct CollectionView: View {
    @Environment(ExperimentStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var selected: UUID?
    @Binding var pushed: UUID?
    let onStartTemplate: (ExperimentTemplate) -> Void

    @State private var filter: CardFilter = .all
    @State private var preview: ExperimentTemplate?

    var body: some View {
        let cards = CardBook.cards(experiments: store.experiments, now: .now, calendar: store.calendar)
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    HStack(spacing: 0) {
                        grid(cards: cards)
                            .frame(maxWidth: 400)
                        Rectangle().fill(Palette.line).frame(width: 0.6)
                        Group {
                            if let id = selected ?? cards.first?.id {
                                CardDetailView(experimentID: id)
                                    .id(id)
                            } else {
                                ContentUnavailableView("カードはまだありません", systemImage: "rectangle.portrait.on.rectangle.portrait", description: Text("実験が終わると、結果がカードになります。"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    grid(cards: cards)
                }
            }
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("図鑑")
            .navigationDestination(item: $pushed) { id in
                CardDetailView(experimentID: id)
            }
            .sheet(item: $preview) { template in
                TemplatePreview(template: template, locked: !ProGate.canUse(template, isPro: purchases.isPro, trialTemplateID: TrialState.templateID)) {
                    preview = nil
                    onStartTemplate(template)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func open(_ card: HabitCard) {
        if sizeClass == .regular {
            withAnimation(.easeOut(duration: 0.25)) { selected = card.id }
        } else {
            pushed = card.id
        }
    }

    private func grid(cards: [HabitCard]) -> some View {
        let slots = CardBook.slots(cards)
        let custom = CardBook.custom(cards)
        let columns = [GridItem(.adaptive(minimum: 100, maximum: 124), spacing: Space.m)]
        return ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                summary(cards: cards)
                Picker("種類", selection: $filter) {
                    ForEach(CardFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if let kind = filter.kind {
                    let matching = cards.filter { $0.kind == kind }
                    if matching.isEmpty {
                        Text("「\(filter.title)」のカードはまだありません。")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    LazyVGrid(columns: columns, spacing: Space.l) {
                        ForEach(matching) { card in
                            Button { open(card) } label: { CardFace(card: card, width: 100).softShadow() }
                                .buttonStyle(.plain)
                        }
                    }
                } else {
                    if !custom.isEmpty {
                        section(title: "じぶんの型", detail: "\(custom.count) 枚") {
                            LazyVGrid(columns: columns, spacing: Space.l) {
                                ForEach(custom) { card in
                                    Button { open(card) } label: { CardFace(card: card, width: 100).softShadow() }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    ForEach(TemplateCategory.allCases) { category in
                        let templates = TemplateLibrary.templates(in: category)
                        let found = templates.filter { slots[$0.id] != nil }.count
                        section(title: category.title, detail: "\(found) / \(templates.count)") {
                            LazyVGrid(columns: columns, spacing: Space.l) {
                                ForEach(templates) { template in
                                    if let card = slots[template.id] {
                                        Button { open(card) } label: { CardFace(card: card, width: 100).softShadow() }
                                            .buttonStyle(.plain)
                                    } else {
                                        Button { preview = template } label: {
                                            EmptySlot(template: template, width: 100, locked: template.isPro && !purchases.isPro)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Space.l)
        }
    }

    private func section<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionTitle(text: title, detail: detail)
            content()
        }
    }

    private func summary(cards: [HabitCard]) -> some View {
        HStack(alignment: .top, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(CardBook.discovered(cards))")
                        .font(Typo.number(.largeTitle))
                        .kerning(-3)
                        .foregroundStyle(Palette.ink)
                    Text("/ \(TemplateLibrary.all.count)")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Palette.inkSoft)
                }
                TagText(text: "集めた枠")
            }
            Spacer()
            count(CardBook.count(cards, kind: .proven), "効いた", Palette.peach.deep)
            count(CardBook.count(cards, kind: .myth), "思い込み", Palette.sky.deep)
            count(CardBook.overturned(cards), "破った", Palette.ink)
        }
    }

    private func count(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(Typo.number(.title2))
                .foregroundStyle(color)
            TagText(text: label)
        }
        .accessibilityElement(children: .combine)
    }
}

/// まだの枠を押したとき：その型の中身と、始めるボタン
struct TemplatePreview: View {
    let template: ExperimentTemplate
    let locked: Bool
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    Image(systemName: template.symbol)
                        .font(.title2.weight(.light))
                        .foregroundStyle(Palette.sky.deep)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Palette.sky.soft))
                    VStack(alignment: .leading, spacing: 2) {
                        TagText(text: template.category.title + (template.isPro ? " · Pro" : ""))
                        Text(template.title)
                            .font(Typo.title(.title3))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(template.reason).font(.subheadline).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Label(template.tip, systemImage: "lightbulb")
                    .font(.footnote).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Label(template.pitfall, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onStart) {
                    Label(locked ? "Pro で始める" : "この実験を始める", systemImage: locked ? "lock" : "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, Space.s)
            }
            .padding(Space.xl)
        }
        .background(Palette.ground.ignoresSafeArea())
    }
}

/// 1 枚のカードの中身：大きなカード・ことば・平均の差・偶然の図・追試（Pro）・共有
struct CardDetailView: View {
    let experimentID: UUID
    @Environment(ExperimentStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false
    @State private var showingPaywall = false
    @State private var combined: Replication.Combined?
    @State private var confirmDelete = false
    @State private var limitNotice = false

    var body: some View {
        ScrollView {
            if let experiment = store.experiment(id: experimentID), let card = CardRules.card(for: experiment) {
                let result = Analyzer.result(for: experiment)
                VStack(spacing: Space.l) {
                    CardFace(card: card, width: 240)
                        .liftedShadow()
                        .padding(.top, Space.m)
                    Text(CardRules.line(card))
                        .font(Typo.title(.headline))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let prediction = card.prediction, let outcome = card.outcome.title {
                        Text("始める前の予想は「\(prediction.title)」→ \(outcome)")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    HStack(spacing: Space.m) {
                        Button { showingShare = true } label: { Label("カードを共有", systemImage: "square.and.arrow.up") }
                            .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                        Button(action: replicate) { Label("もう一度ためす", systemImage: "arrow.clockwise") }
                            .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                    }
                    if limitNotice {
                        Text("無料では同時に \(ProGate.freeActiveLimit) つまで。進行中の実験が終わってから、もう一度ためせます。")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    MeansPanel(result: result, experiment: experiment)
                    ChancePanel(result: result)
                    replicationPanel(experiment)
                    Panel {
                        VStack(alignment: .leading, spacing: Space.s) {
                            SectionTitle(text: "記録", detail: "\(experiment.checkIns.count) / \(experiment.duration) 日")
                            DayDots(experiment: experiment, today: nil, size: 16)
                            Text("濃い点ほど点数が高い日。輪だけの日は、くじのとおりに過ごせなかった日（くらべるのから外しています）。")
                                .font(.caption)
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("この実験を消す", systemImage: "trash")
                    }
                    .buttonStyle(QuietButtonStyle(color: Palette.inkSoft))
                    Text("医療の判断には使わないでください。")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(Space.l)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .sheet(isPresented: $showingShare) {
                    ShareSheet(card: card)
                }
                .task(id: experiment.templateID) { computeCombined(experiment) }
            } else {
                ContentUnavailableView("カードがありません", systemImage: "rectangle.portrait.slash", description: Text("消した実験か、結果が出なかった実験です。"))
                    .padding(.top, Space.xxl)
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("カード")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: .replication)
        }
        .confirmationDialog("この実験とカードを消しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("消す", role: .destructive) {
                store.delete(id: experimentID)
                dismiss()
            }
        }
    }

    private func replicate() {
        guard ProGate.canStartAnother(activeCount: store.activeOwnCount(), isPro: purchases.isPro) else {
            if purchases.isPro {
                withAnimation(.easeOut(duration: 0.25)) { limitNotice = true }
            } else {
                showingPaywall = true
            }
            return
        }
        _ = store.restart(id: experimentID)
    }

    private func computeCombined(_ experiment: Experiment) {
        guard let id = experiment.templateID else { return }
        let runs = Replication.runs(from: store.finishedRuns(templateID: id))
        combined = Replication.combined(runs)
    }

    @ViewBuilder
    private func replicationPanel(_ experiment: Experiment) -> some View {
        if let id = experiment.templateID {
            let count = store.finishedRuns(templateID: id).count
            Panel {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionTitle(text: "追試", detail: "\(count) 回")
                    if count < 2 {
                        Text("同じ実験をもう一度ためすと、2 回分の証拠を合わせて判定できます。1 回だけの結果より、偶然に左右されにくくなります。")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if purchases.isPro, let combined {
                        Text("\(combined.runs) 回分を合わせると、やる日のほうが平均 \(ResultText.signed(combined.meanDifference))。くじを入れ替えて同じくらいの差が出る確率は \(ResultText.percent(combined.pValue))。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("\(count) 回分の記録があります。合わせた判定は Pro で見られます。")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                        Button { showingPaywall = true } label: { Label("Pro で合わせた判定を見る", systemImage: "lock") }
                            .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                    }
                    TagText(text: "回ごとにくじを入れ替える並べ替え検定（20,000 回）")
                }
            }
        }
    }
}

/// やる日・やすむ日の平均。数字は図の上に並べ、棒に重ねない
struct MeansPanel: View {
    let result: ExperimentResult
    let experiment: Experiment

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionTitle(text: "やる日とやすむ日")
                HStack(alignment: .top, spacing: Space.xl) {
                    figure(result.doMean, label: "やる日の平均", arm: .doIt, days: result.doRatings.count)
                    figure(result.restMean, label: "やすむ日の平均", arm: .rest, days: result.restRatings.count)
                }
                Chart {
                    ForEach(Arm.allCases, id: \.self) { arm in
                        let ratings = arm == .doIt ? result.doRatings : result.restRatings
                        let swatch = Palette.swatch(for: arm)
                        if let mean = Analyzer.mean(ratings) {
                            BarMark(x: .value("平均", mean), y: .value("日", arm.title), height: .ratio(0.5))
                                .foregroundStyle(swatch.accent)
                                .cornerRadius(Radius.tag)
                        }
                        ForEach(Array(ratings.enumerated()), id: \.offset) { index, rating in
                            PointMark(x: .value("点", Double(rating)), y: .value("日", arm.title))
                                .foregroundStyle(swatch.deep)
                                .symbolSize(24)
                                .opacity(0.5)
                                .offset(y: CGFloat((index % 5) - 2) * 3)
                        }
                    }
                }
                .chartXScale(domain: 0...5)
                .chartXAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { _ in
                        AxisGridLine().foregroundStyle(Palette.line)
                        AxisValueLabel()
                    }
                }
                .frame(height: 120)
                .accessibilityLabel("やる日とやすむ日の平均の比較")
                Text("1 \(experiment.lowLabel) 〜 5 \(experiment.highLabel)")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func figure(_ value: Double?, label: String, arm: Arm, days: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value.map(ResultText.number) ?? "–")
                .font(Typo.number(.largeTitle))
                .kerning(-3)
                .foregroundStyle(Palette.swatch(for: arm).deep)
            TagText(text: "\(label) · \(days) 日")
        }
    }
}

/// 偶然でも、この差は出る？（くじを全部入れ替えた差の分布）
struct ChancePanel: View {
    let result: ExperimentResult

    var body: some View {
        let buckets = Analyzer.differenceDistribution(result.doRatings, result.restRatings)
        let observed = abs(result.difference ?? 0)
        let total = buckets.reduce(0) { $0 + $1.count }
        Panel {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionTitle(text: "偶然でも、この差は出る？")
                Text("記録した点数はそのままに、くじの割り付けだけを全部の組み合わせ（\(total.formatted()) 通り）で入れ替えて、差を並べました。")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.l) {
                    legend(Palette.peach.accent, "あなたの差（\(ResultText.signed(result.difference ?? 0))）以上")
                    legend(Palette.inkSoft.opacity(0.35), "それより小さい")
                }
                Chart {
                    ForEach(buckets) { bucket in
                        BarMark(x: .value("差", bucket.difference), y: .value("通り", bucket.count), width: .fixed(5))
                            .foregroundStyle(abs(bucket.difference) >= observed - 1e-9 ? Palette.peach.accent : Palette.inkSoft.opacity(0.35))
                    }
                    RuleMark(x: .value("あなたの差", result.difference ?? 0))
                        .foregroundStyle(Palette.peach.deep)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartYAxis(.hidden)
                .chartXAxisLabel("くじを入れ替えたときの差", alignment: .center)
                .frame(height: 150)
                .accessibilityLabel("くじを入れ替えたときの差の分布。あなたの差より外側は \(ResultText.percent(result.pValue ?? 1))")
                if let p = result.pValue {
                    Text("色の付いた棒は全体の \(ResultText.percent(p))。\(ResultText.analogy(p))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Space.xs) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption2).foregroundStyle(Palette.inkSoft)
        }
    }
}

/// カードを画像（1080×1512）にして共有する。名前や日付は入れない
struct ShareSheet: View {
    let card: HabitCard
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    ShareCanvas(card: card)
                        .frame(width: 270, height: 378)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .liftedShadow()
                    Text("名前や日付など、あなたを特定できることは入りません。")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                    if let image {
                        ShareLink(item: image, preview: SharePreview("じぶん実験室のカード", image: image)) {
                            Label("画像を共有する", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text("画像を作れませんでした。開き直してください。")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(Space.xl)
            }
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("カードを共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear(perform: render)
        }
    }

    private func render() {
        let renderer = ImageRenderer(
            content: ShareCanvas(card: card)
                .frame(width: 360, height: 504)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 504)
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        }
    }
}

/// 共有画像の中身（5:7）
struct ShareCanvas: View {
    let card: HabitCard

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 360
            ZStack {
                Palette.ground
                VStack(spacing: 14 * scale) {
                    Text("じぶん実験室")
                        .font(.system(size: 13 * scale, weight: .medium, design: .serif))
                        .kerning(1)
                        .foregroundStyle(Palette.inkSoft)
                    CardFace(card: card, width: 240 * scale)
                        .liftedShadow()
                    Text("くじで「やる日」と「やすむ日」を決めて、自分に効くかを確かめました。")
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * scale)
                }
            }
        }
    }
}
