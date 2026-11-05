import Charts
import SwiftUI

/// 実験ノートを開いたところ：記録表、結果（ハンコ・言葉・グラフ）、偶然の確率の図、コツと落とし穴。
/// 広い画面（iPhone Duo の内側など。horizontal size class が regular）では、記録表と結果を横に並べる。
struct ExperimentDetailView: View {
    let experimentID: UUID
    @Binding var openShare: Bool
    @Binding var scrollToChance: Bool
    let onRecord: (Int) -> Void
    let onDeleted: () -> Void
    let onNext: () -> Void
    let onRestarted: (UUID) -> Void

    @Environment(ExperimentStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var confirmingEnd = false
    @State private var confirmingDelete = false

    var body: some View {
        if let experiment = store.experiment(id: experimentID) {
            let now = Date.now
            let finished = experiment.isFinished(on: now, calendar: store.calendar)
            let today = finished ? nil : experiment.today(on: now, calendar: store.calendar)
            let result = Analyzer.result(for: experiment)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        header(experiment, finished: finished, today: today, result: result)
                        if sizeClass == .regular {
                            HStack(alignment: .top, spacing: Space.xl) {
                                tablePage(experiment, today: today)
                                verdictPage(experiment, result: result, finished: finished)
                            }
                        } else {
                            verdictPage(experiment, result: result, finished: finished)
                            tablePage(experiment, today: today)
                        }
                        if result.verdict != .notEnough {
                            ChancePage(result: result)
                                .id("chance")
                        }
                        if let template = TemplateLibrary.template(id: experiment.templateID) {
                            tipsPage(template)
                        }
                        actions(experiment, finished: finished, today: today, result: result)
                    }
                    .padding(Space.l)
                    .padding(.top, Space.l)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    guard scrollToChance else { return }
                    scrollToChance = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        proxy.scrollTo("chance", anchor: .top)
                    }
                }
            }
            .background(Palette.desk.ignoresSafeArea())
            .navigationTitle(experiment.isSample ? "見本のノート" : "実験ノート")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $openShare) {
                ShareSheet(experiment: experiment, result: result)
            }
            .confirmationDialog("この実験を途中で終えますか？", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("終えて結果を見る") { store.endEarly(id: experiment.id) }
            } message: {
                Text("ここまでの記録で結果を出し、ノートを棚に並べます。")
            }
            .confirmationDialog("このノートを消しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("消す", role: .destructive) {
                    store.delete(id: experiment.id)
                    onDeleted()
                }
            } message: {
                Text("記録も消えます。元に戻せません。")
            }
        }
    }

    // MARK: - ページ

    private func header(_ experiment: Experiment, finished: Bool, today: Int?, result: ExperimentResult) -> some View {
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                PageTitle(text: experiment.title, font: Typo.title(.title2))
                TagText(text: "\(experiment.startDate.formatted(.dateTime.month().day())) から \(experiment.duration) 日", color: Palette.ink)
                Label(experiment.action, systemImage: "bolt")
                    .foregroundStyle(Palette.peach.deep)
                Label(experiment.question + (experiment.nextMorning ? "（翌朝に記録）" : "（夜に記録）"), systemImage: experiment.nextMorning ? "sunrise" : "moon.stars")
                    .foregroundStyle(Palette.sky.deep)
                if !experiment.reason.isEmpty {
                    Text(experiment.reason)
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(DetailText.status(experiment: experiment, finished: finished, today: today, result: result, now: .now, calendar: store.calendar))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(Space.s)
                    .background(Palette.mist.soft)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
        }
    }

    private func tablePage(_ experiment: Experiment, today: Int?) -> some View {
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("記録表").font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                RecordTable(experiment: experiment, today: today)
                RecordLegend()
                Text("数字は記録の点数。濃いほど高い点。点線は、くじを引いてまだ記録していない日。")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func verdictPage(_ experiment: Experiment, result: ExperimentResult, finished: Bool) -> some View {
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .center, spacing: Space.l) {
                    Hanko(verdict: result.verdict, size: 104, inProgress: !finished)
                        .popIn()
                    VStack(alignment: .leading, spacing: Space.xs) {
                        TagText(text: finished ? "結果" : "途中の結果")
                        Text(ResultText.headline(result))
                            .font(Typo.title(.title))
                            .foregroundStyle(Palette.verdict(result.verdict))
                            .minimumScaleFactor(0.8)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let difference = result.difference {
                            Text("差 \(ResultText.signed(difference))")
                                .font(Typo.number(.title2))
                                .kerning(-1)
                                .contentTransition(.numericText())
                                .foregroundStyle(Palette.ink)
                        }
                    }
                }
                if result.doMean != nil || result.restMean != nil {
                    MeansChart(result: result)
                }
                Text(ResultText.detail(result))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if result.skipped > 0 {
                    Text("くじのとおりにできなかった \(result.skipped) 日は、比べるのから外しています。")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }

    private func tipsPage(_ template: ExperimentTemplate) -> some View {
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("この実験のコツ").font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                Label(template.tip, systemImage: "lightbulb")
                    .foregroundStyle(Palette.ink)
                Label(template.pitfall, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Palette.peach.deep)
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func actions(_ experiment: Experiment, finished: Bool, today: Int?, result: ExperimentResult) -> some View {
        VStack(spacing: Space.m) {
            if !finished, let day = experiment.pendingDays(on: .now, calendar: store.calendar).first {
                Button {
                    onRecord(day)
                } label: {
                    Label(DetailText.recordLabel(experiment, day: day, today: today), systemImage: "pencil")
                }
                .buttonStyle(StampButtonStyle())
            }
            if result.verdict != .notEnough {
                Button {
                    openShare = true
                } label: {
                    Label("結果カードを作る", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(StampButtonStyle(swatch: Palette.sky))
            }
            if finished {
                Button {
                    if let id = store.restart(id: experiment.id) { onRestarted(id) }
                } label: {
                    Label("同じ実験をもう一度", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PencilButtonStyle())
                Button(action: onNext) {
                    Label("次の実験を作る", systemImage: "plus")
                }
                .buttonStyle(PencilButtonStyle())
            }
            HStack {
                if !finished {
                    Button("途中で終える") { confirmingEnd = true }
                        .buttonStyle(PencilButtonStyle(color: Palette.sky.deep))
                }
                Spacer()
                Button("ノートを消す", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(PencilButtonStyle(color: Palette.peach.deep))
            }
            Text("医療の判断には使わないでください。体調に関わることは医師に相談してください。")
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 詳細の文（テストできるように画面から分ける）
enum DetailText {
    static func status(experiment: Experiment, finished: Bool, today: Int?, result: ExperimentResult, now: Date, calendar: Calendar) -> String {
        if experiment.endedEarly {
            return "途中で終えた実験です。ここまでの \(experiment.checkIns.count) 日分で結果を出しています。もう一度始めると、くらべる日が増えて結果が確かになります。"
        }
        if finished {
            return "実験は終わりました。結果カードにして残すか、次の実験へ。"
        }
        let pending = experiment.pendingDays(on: now, calendar: calendar)
        let missing = pending.filter { $0 != today }
        if !missing.isEmpty {
            return "記録が抜けている日が \(missing.count) 日あります。思い出せる日はつけましょう。空けたままでも結果は出ます。"
        }
        let left = ResultText.remaining(result)
        if result.verdict == .notEnough {
            return "あと やる日 \(left.doDays) 日・やすむ日 \(left.restDays) 日の記録で、途中の結果が出ます。"
        }
        let days = max(0, experiment.duration - (today ?? 0) - 1)
        return "あと \(days) 日で実験が終わり、ハンコが押されます。"
    }

    static func recordLabel(_ experiment: Experiment, day: Int, today: Int?) -> String {
        if experiment.nextMorning, let today, day == today - 1 { return "けさの記録をする" }
        if day == today { return "今日の分を記録する" }
        return "\(day + 1) 日目の分を記録する"
    }
}

/// やる日・やすむ日の平均（棒）と、1 日ずつの点（Swift Charts）
struct MeansChart: View {
    let result: ExperimentResult

    var body: some View {
        Chart {
            ForEach(Arm.allCases, id: \.self) { arm in
                let ratings = arm == .doIt ? result.doRatings : result.restRatings
                let swatch = Palette.swatch(for: arm)
                if let mean = Analyzer.mean(ratings) {
                    BarMark(x: .value("日", arm.title), y: .value("平均", mean), width: .ratio(0.5))
                        .foregroundStyle(swatch.accent)
                        .cornerRadius(Radius.tag)
                        .annotation(position: .top) {
                            Text(ResultText.number(mean))
                                .font(.system(.callout, design: .serif).weight(.regular).monospacedDigit())
                                .foregroundStyle(swatch.deep)
                        }
                }
                ForEach(Array(ratings.enumerated()), id: \.offset) { index, rating in
                    PointMark(x: .value("日", arm.title), y: .value("点", Double(rating) + Double((index % 5) - 2) * 0.06))
                        .foregroundStyle(swatch.deep)
                        .symbolSize(28)
                        .opacity(0.6)
                }
            }
        }
        .chartYScale(domain: 0...5.8)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5]) { _ in
                AxisGridLine().foregroundStyle(Palette.grid)
                AxisValueLabel()
            }
        }
        .frame(height: 180)
        .accessibilityLabel("やる日とやすむ日の平均の比較")
    }
}

/// 「偶然でもこのくらいの差が出る確率」の図とたとえ
struct ChancePage: View {
    let result: ExperimentResult

    var body: some View {
        let buckets = Analyzer.differenceDistribution(result.doRatings, result.restRatings)
        let observed = abs(result.difference ?? 0)
        let total = buckets.reduce(0) { $0 + $1.count }
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("偶然でも、この差は出る？").font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                Text("記録した点数はそのままに、くじの割り付けだけを全部の組み合わせ（\(total.formatted()) 通り）で入れ替えて、「やる日の平均 − やすむ日の平均」を並べました。")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Chart {
                    ForEach(buckets) { bucket in
                        BarMark(x: .value("差", bucket.difference), y: .value("通り", bucket.count), width: .fixed(5))
                            .foregroundStyle(abs(bucket.difference) >= observed - 1e-9 ? Palette.peach.accent : Palette.inkSoft.opacity(0.35))
                    }
                    RuleMark(x: .value("あなたの差", result.difference ?? 0))
                        .foregroundStyle(Palette.peach.deep)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("あなたの差")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.peach.deep)
                        }
                }
                .chartYAxis(.hidden)
                .padding(.top, Space.l)
                .chartXAxisLabel("くじを入れ替えたときの差", alignment: .center)
                .frame(height: 170)
                .accessibilityLabel("くじを入れ替えたときの差の分布。あなたの差より外側は \(ResultText.percent(result.pValue ?? 1))")
                if let p = result.pValue {
                    Text("朱色の棒（あなたの差と同じか、もっと大きい差）は全体の \(ResultText.percent(p))。\(ResultText.analogy(p))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 結果カード（1080×1920）を作って共有する
struct ShareSheet: View {
    let experiment: Experiment
    let result: ExperimentResult
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    ShareCard(experiment: experiment, result: result)
                        .frame(width: 270, height: 480)
                        .scaleEffect(1)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.page, style: .continuous))
                        .liftedShadow()
                    Text("名前や日付など、あなたを特定できることは入りません。数字と言葉だけのカードです。")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                    if let image {
                        ShareLink(item: image, preview: SharePreview("じぶん実験室の結果", image: image)) {
                            Label("画像を共有する", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(StampButtonStyle(swatch: Palette.sky))
                    } else {
                        Text("カードを作れませんでした。もう一度開き直してください。")
                            .font(.footnote)
                            .foregroundStyle(Palette.peach.deep)
                    }
                }
                .padding(Space.xl)
            }
            .background(Palette.desk.ignoresSafeArea())
            .navigationTitle("結果カード")
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
            content: ShareCard(experiment: experiment, result: result)
                .frame(width: 360, height: 640)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 640)
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        }
    }
}

/// 共有カードの中身（360×640 の比率。数字と言葉だけ）
struct ShareCard: View {
    let experiment: Experiment
    let result: ExperimentResult

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 360
            ZStack {
                Palette.paper
                GridPaper(spacing: 18 * scale, marginX: 36 * scale)
                VStack(alignment: .leading, spacing: 18 * scale) {
                    Text("じぶん実験室")
                        .font(.system(size: 14 * scale, weight: .medium, design: .serif))
                        .kerning(1)
                        .foregroundStyle(Palette.inkSoft)
                    LabelSticker(text: experiment.title, color: Palette.peach.accent, font: .system(size: 22 * scale, weight: .medium, design: .serif))
                    Text("\(experiment.duration) 日の実験 ・ 記録 \(experiment.checkIns.count) 日")
                        .font(.system(size: 13 * scale))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Hanko(verdict: result.verdict, size: 150 * scale)
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 24 * scale) {
                        number(result.doMean, label: "やる日", color: Palette.peach.deep, scale: scale)
                        number(result.restMean, label: "やすむ日", color: Palette.sky.deep, scale: scale)
                    }
                    if let difference = result.difference, let p = result.pValue {
                        Text("差 \(ResultText.signed(difference)) ・ 偶然の確率 \(ResultText.percent(p))")
                            .font(.system(size: 15 * scale, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.ink)
                    }
                    Text("くじで「やる日」と「やすむ日」を決めて、自分に効くかを確かめました。")
                        .font(.system(size: 12 * scale))
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(.leading, 52 * scale)
                .padding(.trailing, 28 * scale)
                .padding(.vertical, 40 * scale)
            }
        }
    }

    private func number(_ value: Double?, label: String, color: Color, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map(ResultText.number) ?? "–")
                .font(.system(size: 52 * scale, weight: .regular, design: .serif).monospacedDigit())
                .kerning(-3)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12 * scale, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(Palette.inkSoft)
        }
    }
}
