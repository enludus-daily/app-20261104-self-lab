import Foundation

// 遊びの決まり（画面から切り離して、テストできる形にする）。
// 記録した点数が、そのままカードの種類と★を決める（飾りのごほうびではなく、統計の結果がカードになる）。

/// カードの種類（終わった実験の結果）
enum CardKind: String, Sendable, CaseIterable {
    /// 効いた（やる日のほうがよい）
    case proven
    /// 思い込みだった（はっきりした差はない）
    case myth
    /// 逆効果（やる日のほうがわるい）
    case backfire

    var title: String {
        switch self {
        case .proven: "効いた"
        case .myth: "思い込みだった"
        case .backfire: "逆効果だった"
        }
    }

    var symbol: String {
        switch self {
        case .proven: "arrow.up.heart"
        case .myth: "cloud"
        case .backfire: "arrow.down.heart"
        }
    }

    /// 図鑑で同じ型に何枚あるとき、どれを表に出すか（大きいほど前）
    var rank: Int {
        switch self {
        case .proven: 3
        case .backfire: 2
        case .myth: 1
        }
    }
}

/// 予想と結果のくらべ
enum PredictionOutcome: Equatable, Sendable {
    /// 予想していない・半信半疑
    case none
    /// 予想どおり
    case matched
    /// 思い込みがひっくり返った
    case overturned

    static func of(prediction: Prediction?, kind: CardKind) -> PredictionOutcome {
        switch (prediction, kind) {
        case (.works, .proven), (.doesNotWork, .myth), (.doesNotWork, .backfire): .matched
        case (.works, .myth), (.works, .backfire), (.doesNotWork, .proven): .overturned
        default: .none
        }
    }

    var title: String? {
        switch self {
        case .none: nil
        case .matched: "予想どおり"
        case .overturned: "思い込みを破った"
        }
    }
}

/// 1 枚のカード（終わった実験 1 つから 1 枚）
struct HabitCard: Identifiable, Equatable, Sendable {
    var experimentID: UUID
    var templateID: String?
    var title: String
    var action: String
    var symbol: String
    var category: TemplateCategory?
    var kind: CardKind
    /// 証拠の強さ（1〜3）
    var stars: Int
    var doMean: Double
    var restMean: Double
    var difference: Double
    var pValue: Double
    /// くらべた日数（くじのとおりに過ごせた日）
    var comparedDays: Int
    var duration: Int
    var prediction: Prediction?
    var outcome: PredictionOutcome
    var endedEarly: Bool
    var isSample: Bool

    var id: UUID { experimentID }
}

enum CardRules {
    /// 証拠の強さ。差があるときは偶然の確率で、差がないときは調べた日数で決まる
    static func stars(verdict: ExperimentResult.Verdict, pValue: Double, comparedDays: Int) -> Int {
        switch verdict {
        case .better, .worse:
            if pValue <= 0.01 { return 3 }
            if pValue <= 0.05 { return 2 }
            return 1
        case .noClearDifference:
            return comparedDays >= 12 ? 2 : 1
        case .notEnough:
            return 0
        }
    }

    static func kind(_ verdict: ExperimentResult.Verdict) -> CardKind? {
        switch verdict {
        case .better: .proven
        case .worse: .backfire
        case .noClearDifference: .myth
        case .notEnough: nil
        }
    }

    /// 終わった実験からカードを作る（結果が出なかったものは nil）
    static func card(for experiment: Experiment) -> HabitCard? {
        let result = Analyzer.result(for: experiment)
        guard let kind = kind(result.verdict), let p = result.pValue,
              let doMean = result.doMean, let restMean = result.restMean else { return nil }
        let compared = result.doRatings.count + result.restRatings.count
        let template = TemplateLibrary.template(id: experiment.templateID)
        return HabitCard(
            experimentID: experiment.id,
            templateID: experiment.templateID,
            title: experiment.title,
            action: experiment.action,
            symbol: TemplateLibrary.symbol(for: experiment),
            category: template?.category,
            kind: kind,
            stars: stars(verdict: result.verdict, pValue: p, comparedDays: compared),
            doMean: doMean,
            restMean: restMean,
            difference: doMean - restMean,
            pValue: p,
            comparedDays: compared,
            duration: experiment.duration,
            prediction: experiment.prediction,
            outcome: PredictionOutcome.of(prediction: experiment.prediction, kind: kind),
            endedEarly: experiment.endedEarly,
            isSample: experiment.isSample
        )
    }

    /// カードの言葉
    static func line(_ card: HabitCard) -> String {
        switch card.kind {
        case .proven: "あなたには効いていました。続ける価値あり。"
        case .myth: "やってもやらなくても、同じくらいでした。やめても損はなさそうです。"
        case .backfire: "やらない日のほうが調子がよかった。やり方を変えるか、やめどき。"
        }
    }
}

/// 図鑑（型ごとの枠と、集めたカード）
enum CardBook {
    /// 終わった実験のカード（新しい順）
    static func cards(experiments: [Experiment], now: Date, calendar: Calendar) -> [HabitCard] {
        experiments
            .filter { $0.isFinished(on: now, calendar: calendar) }
            .sorted { $0.startDate > $1.startDate }
            .compactMap(CardRules.card(for:))
    }

    /// 同じ枠に何枚あっても、表に出すのは 1 枚（★が多い → 種類 → 新しい）
    static func best(_ cards: [HabitCard]) -> HabitCard? {
        cards.enumerated().max { lhs, rhs in
            if lhs.element.stars != rhs.element.stars { return lhs.element.stars < rhs.element.stars }
            if lhs.element.kind.rank != rhs.element.kind.rank { return lhs.element.kind.rank < rhs.element.kind.rank }
            return lhs.offset > rhs.offset  // 先にあるほうが新しい
        }?.element
    }

    /// 型の枠ごとのカード（templateID → 表に出す 1 枚）
    static func slots(_ cards: [HabitCard]) -> [String: HabitCard] {
        var grouped: [String: [HabitCard]] = [:]
        for card in cards {
            guard let id = card.templateID else { continue }
            grouped[id, default: []].append(card)
        }
        return grouped.compactMapValues(best)
    }

    /// 自分で書いた実験のカード（型の枠に入らない）
    static func custom(_ cards: [HabitCard]) -> [HabitCard] {
        cards.filter { card in card.templateID.flatMap(TemplateLibrary.template(id:)) == nil }
    }

    /// 集めた枠の数（型の枠＋自分で書いたもの）
    static func discovered(_ cards: [HabitCard]) -> Int {
        slots(cards).count + custom(cards).count
    }

    /// 同じ型を 2 回以上ためした（追試の）カード
    static func replicated(_ cards: [HabitCard]) -> [String: [HabitCard]] {
        var grouped: [String: [HabitCard]] = [:]
        for card in cards { if let id = card.templateID { grouped[id, default: []].append(card) } }
        return grouped.filter { $0.value.count >= 2 }
    }

    static func count(_ cards: [HabitCard], kind: CardKind) -> Int {
        cards.filter { $0.kind == kind }.count
    }

    static func overturned(_ cards: [HabitCard]) -> Int {
        cards.filter { $0.outcome == .overturned }.count
    }
}

/// けさの開封：1 枚ずつめくるカードの並び
enum DeckCard: Equatable, Identifiable, Sendable {
    /// きのうの記録のふりかえり
    case recap(experimentID: UUID, day: Int)
    /// きのうの記録がまだ（ここで記録すると先へ進める）
    case missing(experimentID: UUID, day: Int)
    /// 集まった証拠と、結果発表までの日数
    case evidence(experimentID: UUID)
    /// きょうのくじ（伏せてある）
    case lot(experimentID: UUID, day: Int)
    /// 結果発表（カードを手に入れる）
    case verdict(experimentID: UUID)

    var experimentID: UUID {
        switch self {
        case .recap(let id, _), .missing(let id, _), .evidence(let id), .lot(let id, _), .verdict(let id): id
        }
    }

    var id: String {
        switch self {
        case .recap(let id, let day): "recap-\(id)-\(day)"
        case .missing(let id, let day): "missing-\(id)-\(day)"
        case .evidence(let id): "evidence-\(id)"
        case .lot(let id, let day): "lot-\(id)-\(day)"
        case .verdict(let id): "verdict-\(id)"
        }
    }
}

enum MorningDeck {
    /// まだめくっていないカード。結果発表が先、つぎに進行中の実験（古い順）
    static func cards(experiments: [Experiment], now: Date, calendar: Calendar) -> [DeckCard] {
        var verdicts: [DeckCard] = []
        var daily: [DeckCard] = []
        for experiment in experiments.sorted(by: { $0.startDate < $1.startDate }) {
            if experiment.isFinished(on: now, calendar: calendar) {
                if experiment.announced != true, CardRules.card(for: experiment) != nil {
                    verdicts.append(.verdict(experimentID: experiment.id))
                }
                continue
            }
            guard let today = experiment.today(on: now, calendar: calendar), !experiment.isRevealed(day: today) else { continue }
            if today > 0 {
                let previous = today - 1
                if experiment.checkIn(day: previous) != nil {
                    daily.append(.recap(experimentID: experiment.id, day: previous))
                } else if experiment.pendingDays(on: now, calendar: calendar).contains(previous) {
                    daily.append(.missing(experimentID: experiment.id, day: previous))
                }
            }
            daily.append(.evidence(experimentID: experiment.id))
            daily.append(.lot(experimentID: experiment.id, day: today))
        }
        return verdicts + daily
    }

    /// 結果発表まで、あと何日（今日を数えない）
    static func daysUntilVerdict(_ experiment: Experiment, today: Int) -> Int {
        max(0, experiment.duration - 1 - today + experiment.recordLag)
    }
}

// MARK: - Pro

/// Pro で開くもの（判定は 1 か所）
enum ProGate {
    static let freeActiveLimit = 1
    static let proActiveLimit = 3

    static func activeLimit(isPro: Bool) -> Int { isPro ? proActiveLimit : freeActiveLimit }

    static func canStartAnother(activeCount: Int, isPro: Bool) -> Bool {
        activeCount < activeLimit(isPro: isPro)
    }

    /// Pro の型を使えるか。Pro でなくても、お試しで 1 つだけ（同じ型ならやり直しても使える）
    static func canUse(_ template: ExperimentTemplate, isPro: Bool, trialTemplateID: String?) -> Bool {
        guard template.isPro else { return true }
        return isPro || trialTemplateID == nil || trialTemplateID == template.id
    }
}

/// Pro の中身（画面とテストで同じものを使う）
enum ProFeature: CaseIterable, Identifiable {
    case parallel, templates, replication, export

    var id: Self { self }

    var title: String {
        switch self {
        case .parallel: "実験を 3 つ同時に"
        case .templates: "追加の型 \(TemplateLibrary.proCount)"
        case .replication: "追試の合わせた判定"
        case .export: "記録の書き出し（CSV）"
        }
    }

    var detail: String {
        switch self {
        case .parallel: "朝・仕事・夜の習慣を並べて確かめられます。無料は 1 つずつ。"
        case .templates: "勉強・仕事 12、人と休日 12。図鑑の枠が \(TemplateLibrary.freeCount) から \(TemplateLibrary.all.count) に。1 つは無料で試せます。"
        case .replication: "同じ実験を 2 回以上。回ごとにくじを入れ替える並べ替え検定で、合わせた結果を出します。"
        case .export: "日付・くじ・点数・メモを表計算で開ける形に。"
        }
    }

    var symbol: String {
        switch self {
        case .parallel: "square.stack.3d.up"
        case .templates: "rectangle.portrait.on.rectangle.portrait"
        case .replication: "arrow.triangle.2.circlepath"
        case .export: "tablecells"
        }
    }
}

/// 追試：同じ型を 2 回以上ためした結果を合わせて判定する（Pro）。
/// 回ごとにくじの割り付けを入れ替え（層別の並べ替え検定）、回ごとの差の平均をくらべる。
/// 組み合わせが多いので、種を固定した乱数で 20,000 回入れ替える（同じ入力なら同じ答え）。
enum Replication {
    struct Run: Equatable, Sendable {
        var doRatings: [Int]
        var restRatings: [Int]
    }

    struct Combined: Equatable, Sendable {
        var runs: Int
        var meanDifference: Double
        var pValue: Double
    }

    static let samples = 20_000

    static func runs(from experiments: [Experiment]) -> [Run] {
        experiments.map { experiment in
            let result = Analyzer.result(for: experiment)
            return Run(doRatings: result.doRatings, restRatings: result.restRatings)
        }
        .filter { !$0.doRatings.isEmpty && !$0.restRatings.isEmpty }
    }

    static func combined(_ runs: [Run], samples: Int = samples, seed: UInt64 = 0x5EED) -> Combined? {
        let usable = runs.filter { !$0.doRatings.isEmpty && !$0.restRatings.isEmpty }
        guard usable.count >= 2, samples > 0 else { return nil }
        func statistic(_ groups: [(a: [Int], b: [Int])]) -> Double {
            let total = groups.reduce(0.0) { sum, g in
                sum + Double(g.a.reduce(0, +)) / Double(g.a.count) - Double(g.b.reduce(0, +)) / Double(g.b.count)
            }
            return total / Double(groups.count)
        }
        let observed = statistic(usable.map { (a: $0.doRatings, b: $0.restRatings) })
        var rng = SplitMix64(state: seed)
        var extreme = 0
        for _ in 0..<samples {
            var groups: [(a: [Int], b: [Int])] = []
            for run in usable {
                var values = run.doRatings + run.restRatings
                let k = run.doRatings.count
                // 先頭 k 個を無作為に選ぶ（Fisher–Yates の途中まで）
                for i in 0..<k {
                    let j = i + Int(rng.next() % UInt64(values.count - i))
                    values.swapAt(i, j)
                }
                groups.append((a: Array(values[0..<k]), b: Array(values[k...])))
            }
            if abs(statistic(groups)) >= abs(observed) - 1e-9 { extreme += 1 }
        }
        // 観測した割り付けも 1 通りとして数える（p が 0 にならない）
        let p = Double(extreme + 1) / Double(samples + 1)
        return Combined(runs: usable.count, meanDifference: observed, pValue: p)
    }
}

/// 記録の書き出し（Pro）。表計算で開ける CSV
enum CSVExport {
    static func text(_ experiments: [Experiment], calendar: Calendar) -> String {
        var lines = ["実験,日,日付,くじ,点数,くじのとおり,メモ"]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        for experiment in experiments.sorted(by: { $0.startDate < $1.startDate }) {
            for checkIn in experiment.checkIns.sorted(by: { $0.day < $1.day }) {
                let arm = experiment.arm(day: checkIn.day)?.title ?? ""
                let date = formatter.string(from: experiment.date(ofDay: checkIn.day, calendar: calendar))
                let fields = [
                    experiment.title, "\(checkIn.day + 1)", date, arm, "\(checkIn.rating)",
                    checkIn.followed ? "はい" : "いいえ", checkIn.note,
                ]
                lines.append(fields.map(escape).joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
