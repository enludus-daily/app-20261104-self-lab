import SwiftUI

/// けさの開封：きのうの記録 → 集まった証拠 → きょうのくじ（伏せたカードをめくる）。終わった実験は結果発表（カードを手に入れる）。
/// 記録が抜けていると、その場で記録しないと先のカードが出ない（しんどい記録が、遊びの入力になる）。
struct RevealView: View {
    let deck: [DeckCard]
    var initialIndex = 0
    var initiallyFlipped = false

    @Environment(ExperimentStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var flipped: Set<String> = []
    @State private var flipCount = 0
    @State private var verdictCount = 0
    @State private var recordCount = 0
    @State private var showingPaywall = false
    @State private var prepared = false

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width - 56, (proxy.size.height - 250) / CardMetrics.aspect, 340)
            VStack(spacing: Space.l) {
                topBar
                Spacer(minLength: 0)
                if deck.indices.contains(index) {
                    cardView(deck[index], width: max(cardWidth, 180))
                        .id(deck[index].id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
                Spacer(minLength: 0)
                bottomBar
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .haptic(.selection, trigger: flipCount)
        .haptic(.success, trigger: verdictCount)
        .haptic(.success, trigger: recordCount)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: .afterCard)
        }
        .onAppear {
            guard !prepared else { return }
            prepared = true
            index = min(initialIndex, max(deck.count - 1, 0))
            if initiallyFlipped, deck.indices.contains(index) { flipped.insert(deck[index].id) }
        }
    }

    // MARK: - 上と下

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("とじる")
            Spacer()
            HStack(spacing: 6) {
                ForEach(deck.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? Palette.sky.deep : Palette.line)
                        .frame(width: i == index ? 18 : 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.25), value: index)
            Spacer()
            Text("\(min(index + 1, deck.count)) / \(deck.count)")
                .font(Typo.number(.footnote))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 44)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Space.s) {
            if deck.indices.contains(index) {
                Text(caption(for: deck[index]))
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
                Button(action: primaryAction) {
                    Text(primaryTitle(for: deck[index]))
                }
                .buttonStyle(PrimaryButtonStyle(swatch: Palette.sky))
                .frame(maxWidth: 420)
            } else {
                Button("とじる") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 420)
            }
        }
    }

    private func needsFlip(_ card: DeckCard) -> Bool {
        switch card {
        case .lot, .verdict: !flipped.contains(card.id)
        default: false
        }
    }

    private func primaryTitle(for card: DeckCard) -> String {
        if needsFlip(card) { return "めくる" }
        if case .missing = card { return "あとで記録する" }
        return index >= deck.count - 1 ? "きょうを始める" : "つぎへ"
    }

    private func caption(for card: DeckCard) -> String {
        switch card {
        case .recap: return "きのうの記録です。1 日分の証拠になりました。"
        case .missing: return "きのうの分を記録すると、証拠が 1 枚増えます。"
        case .evidence: return "結果は最後の日まで伏せておきます（途中で見ると、偶然に振り回されるため）。"
        case .lot: return needsFlip(card) ? "カードをタップしてもめくれます。" : "くじは公平。思い込みからも、気分からも。"
        case .verdict: return needsFlip(card) ? "記録した点数を、くじを入れ替えた全部の組み合わせとくらべました。" : "図鑑に入りました。"
        }
    }

    private func primaryAction() {
        guard deck.indices.contains(index) else { return dismiss() }
        let card = deck[index]
        if needsFlip(card) {
            flip(card)
            return
        }
        advance()
    }

    private func advance() {
        if index >= deck.count - 1 {
            dismiss()
            return
        }
        if reduceMotion {
            index += 1
        } else {
            withAnimation(.easeOut(duration: 0.35)) { index += 1 }
        }
    }

    private func flip(_ card: DeckCard) {
        guard !flipped.contains(card.id) else { return }
        switch card {
        case .lot(let id, let day):
            store.reveal(id: id, day: day)
            flipCount += 1
        case .verdict(let id):
            store.announce(id: id)
            verdictCount += 1
        default:
            break
        }
        if reduceMotion {
            flipped.insert(card.id)
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { _ = flipped.insert(card.id) }
        }
    }

    // MARK: - カード

    @ViewBuilder
    private func cardView(_ card: DeckCard, width: CGFloat) -> some View {
        if let experiment = store.experiment(id: card.experimentID) {
            switch card {
            case .recap(_, let day):
                RecapCard(experiment: experiment, day: day, width: width)
            case .missing(_, let day):
                MissingCard(experiment: experiment, day: day, width: width) { rating, followed in
                    if store.record(id: experiment.id, day: day, rating: rating, followed: followed) {
                        recordCount += 1
                        Task {
                            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 650))
                            advance()
                        }
                    }
                }
            case .evidence:
                EvidenceCard(experiment: experiment, width: width)
            case .lot(_, let day):
                let isFlipped = flipped.contains(card.id)
                FlipCard(flipped: isFlipped) {
                    LotFace(experiment: experiment, day: day, width: width)
                } back: {
                    CardBack(width: width, label: "きょうのくじ", caption: experiment.title)
                }
                .floatingShadow()
                .onTapGesture { flip(card) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isFlipped ? "きょうは\(experiment.arm(day: day)?.title ?? "")" : "きょうのくじ。めくる")
            case .verdict:
                let isFlipped = flipped.contains(card.id)
                VStack(spacing: Space.m) {
                    FlipCard(flipped: isFlipped) {
                        if let habit = CardRules.card(for: experiment) {
                            CardFace(card: habit, width: width)
                        }
                    } back: {
                        CardBack(width: width, label: "結果発表", caption: experiment.title)
                    }
                    .floatingShadow()
                    .onTapGesture { flip(card) }
                    .accessibilityAddTraits(.isButton)
                    if isFlipped, !purchases.isPro {
                        Button {
                            showingPaywall = true
                        } label: {
                            Label("Pro なら追試を合わせて判定", systemImage: "sparkles")
                                .font(.footnote.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.sky.deep)
                        .transition(.opacity)
                    }
                }
            }
        } else {
            CardBack(width: width, label: "見つかりません", caption: "消した実験です")
        }
    }
}

/// きのうの記録（ふりかえり）
struct RecapCard: View {
    let experiment: Experiment
    let day: Int
    let width: CGFloat

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        let arm = experiment.arm(day: day) ?? .doIt
        let swatch = Palette.swatch(for: arm)
        let checkIn = experiment.checkIn(day: day)
        ZStack {
            CardFrame(swatch: swatch, scale: scale)
            VStack(spacing: 12 * scale) {
                Text("きのう · \(day + 1) 日目")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Palette.inkSoft)
                ArmPill(arm: arm)
                Spacer(minLength: 0)
                Text(experiment.question)
                    .font(.system(size: 15 * scale, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                HStack(alignment: .firstTextBaseline, spacing: 4 * scale) {
                    Text("\(checkIn?.rating ?? 0)")
                        .font(.system(size: 84 * scale, weight: .regular, design: .serif).monospacedDigit())
                        .kerning(-3)
                        .foregroundStyle(swatch.deep)
                    Text("/ 5")
                        .font(.system(size: 16 * scale, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.inkSoft)
                }
                HStack {
                    Text("1 \(experiment.lowLabel)")
                    Spacer()
                    Text("\(experiment.highLabel) 5")
                }
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                Text(checkIn?.followed == false ? "くじのとおりにできなかった日（くらべるのから外します）" : "くじのとおりに過ごせました")
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24 * scale)
            .padding(.vertical, 26 * scale)
        }
        .frame(width: width, height: CardMetrics.height(for: width))
        .liftedShadow()
        .accessibilityElement(children: .combine)
    }
}

/// きのうの記録がまだ。その場で 1〜5 を選ぶと記録して先へ
struct MissingCard: View {
    let experiment: Experiment
    let day: Int
    let width: CGFloat
    let onRecord: (Int, Bool) -> Void

    @State private var rating: Int?
    @State private var followed = true

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        let arm = experiment.arm(day: day) ?? .doIt
        let swatch = Palette.swatch(for: arm)
        ZStack {
            CardFrame(swatch: Palette.mist, scale: scale)
            VStack(spacing: 12 * scale) {
                Text(experiment.nextMorning ? "けさの記録 · \(day + 1) 日目の翌朝" : "きのうの記録 · \(day + 1) 日目")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                ArmPill(arm: arm)
                Spacer(minLength: 0)
                Text(experiment.question)
                    .font(.system(size: 18 * scale, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6 * scale) {
                    ForEach(Array(Experiment.ratingRange), id: \.self) { value in
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) { rating = value }
                            onRecord(value, followed)
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 20 * scale, weight: .regular, design: .serif).monospacedDigit())
                                .foregroundStyle(rating == value ? .white : Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Circle().fill(rating == value ? swatch.deep : swatch.soft))
                        }
                        .buttonStyle(.plain)
                        .disabled(rating != nil)
                        .accessibilityLabel("\(value)")
                    }
                }
                HStack {
                    Text("1 \(experiment.lowLabel)")
                    Spacer()
                    Text("\(experiment.highLabel) 5")
                }
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                Toggle(isOn: $followed) {
                    Text("くじのとおりに過ごせた")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }
                .tint(swatch.deep)
                .disabled(rating != nil)
            }
            .padding(.horizontal, 22 * scale)
            .padding(.vertical, 24 * scale)
        }
        .frame(width: width, height: CardMetrics.height(for: width))
        .liftedShadow()
    }
}

/// 集まった証拠
struct EvidenceCard: View {
    let experiment: Experiment
    let width: CGFloat
    @Environment(ExperimentStore.self) private var store

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        let today = experiment.today(on: .now, calendar: store.calendar) ?? 0
        let recorded = experiment.checkIns.count
        let left = MorningDeck.daysUntilVerdict(experiment, today: today)
        ZStack {
            CardFrame(swatch: Palette.sky, scale: scale)
            VStack(spacing: 12 * scale) {
                Text("集まった証拠")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Palette.inkSoft)
                Text(experiment.title)
                    .font(.system(size: 16 * scale, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4 * scale) {
                    Text("\(recorded)")
                        .font(.system(size: 72 * scale, weight: .regular, design: .serif).monospacedDigit())
                        .kerning(-3)
                        .foregroundStyle(Palette.sky.deep)
                    Text("/ \(experiment.duration) 日")
                        .font(.system(size: 15 * scale, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.inkSoft)
                }
                DayDots(experiment: experiment, today: today, size: 12 * scale)
                    .frame(maxWidth: 200 * scale)
                Spacer(minLength: 0)
                Text(left == 0 ? "あすの朝、結果発表" : "結果発表まで あと \(left) 日")
                    .font(.system(size: 14 * scale, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text(LabNotes.note(seed: experiment.seed, day: today))
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22 * scale)
            .padding(.vertical, 24 * scale)
        }
        .frame(width: width, height: CardMetrics.height(for: width))
        .liftedShadow()
        .accessibilityElement(children: .combine)
    }
}

/// きょうのくじの表
struct LotFace: View {
    let experiment: Experiment
    let day: Int
    let width: CGFloat

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        let arm = experiment.arm(day: day) ?? .doIt
        let swatch = Palette.swatch(for: arm)
        ZStack {
            CardFrame(swatch: swatch, scale: scale)
            VStack(spacing: 12 * scale) {
                Text("\(day + 1) 日目のくじ")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                Image(systemName: arm == .doIt ? "sun.max" : "moon")
                    .font(.system(size: 54 * scale, weight: .light))
                    .foregroundStyle(swatch.deep)
                Text(arm.title)
                    .font(.system(size: 40 * scale, weight: .regular, design: .serif))
                    .kerning(-1)
                    .foregroundStyle(Palette.ink)
                Text(arm == .doIt ? "きょうは「\(experiment.action)」" : "きょうは、いつもどおりに過ごす（\(experiment.action)はしない）")
                    .font(.system(size: 14 * scale, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                VStack(spacing: 2 * scale) {
                    Text(experiment.nextMorning ? "あすの朝に聞くこと" : "今夜聞くこと")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .kerning(0.6)
                        .foregroundStyle(Palette.inkSoft)
                    Text(experiment.question)
                        .font(.system(size: 13 * scale, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 22 * scale)
            .padding(.vertical, 24 * scale)
        }
        .frame(width: width, height: CardMetrics.height(for: width))
    }
}

/// 証拠のカードのひとこと（小さな驚き。種と日で決まる）
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
        "効かないと分かるのも、立派な結果。「思い込みだった」カードも図鑑に入ります。",
        "今日の自分を、きのうの自分とくらべる実験です。",
        "記録の時刻をそろえると、くらべやすくなります。",
        "メモは一言で十分。あとで読むと発見があります。",
        "やる日は、いつもよりほんの少しだけ丁寧に。",
        "やすむ日は「いつもどおり」がいちばんの仕事。",
        "結果の前に、手を止めずにもう 1 日。",
        "偶然を見分けるには、日数が味方です。",
        "★の数は、偶然では説明しにくいほど増えます。",
        "途中で結果を見ないのは、偶然の波に振り回されないため。",
        "図鑑は、あなただけの取扱説明書になります。",
        "思いつきを確かめる人は、意外と少ない。",
        "小さな差でも、続ければ見えてきます。",
        "「なんとなく」を数字にすると、人にも話しやすくなります。",
        "今日のくじは、今日だけのもの。",
        "実験の途中で条件を変えないのがコツです。",
        "朝と夜で気分は変わる。だから同じ時間に聞きます。",
        "やる日にできなかったら、正直に「できなかった」で。",
        "1 つの実験に 1 つの問い。欲張らないのがコツ。",
        "同じ型をもう一度ためすと、証拠が重なります（追試）。",
        "続けた日数より、確かめた数を誇りに。",
        "今日の記録が、何日かあとの答えになります。",
    ]

    static func note(seed: UInt64, day: Int) -> String {
        var rng = SplitMix64(state: seed &+ UInt64(max(day, 0)) &* 0x9E37_79B9)
        return all[Int(rng.next() % UInt64(all.count))]
    }
}
