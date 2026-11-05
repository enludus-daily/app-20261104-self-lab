import Foundation

/// 種から同じ乱数の列を作る（SplitMix64）。くじの割り付けを保存せずに毎回同じに作るため
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// やる日とやすむ日を半分ずつ、順番をくじで決める。同じ側が長く続かないようにする。
enum Scheduler {
    /// 同じ側が続いてよい日数
    static let maxRun = 3

    static func schedule(days: Int, seed: UInt64) -> [Arm] {
        guard days > 0 else { return [] }
        var rng = SplitMix64(state: seed)
        let base = (0..<days).map { $0 < (days + 1) / 2 ? Arm.doIt : Arm.rest }
        var result = shuffle(base, using: &rng)
        var attempts = 1
        while longestRun(result) > maxRun && attempts < 500 {
            result = shuffle(base, using: &rng)
            attempts += 1
        }
        return result
    }

    /// Fisher–Yates（標準の shuffled は OS で手順が変わりうるので自分で書く）
    static func shuffle(_ items: [Arm], using rng: inout SplitMix64) -> [Arm] {
        var items = items
        guard items.count > 1 else { return items }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            items.swapAt(i, j)
        }
        return items
    }

    static func longestRun(_ arms: [Arm]) -> Int {
        var longest = 0
        var current = 0
        var previous: Arm?
        for arm in arms {
            current = arm == previous ? current + 1 : 1
            previous = arm
            longest = max(longest, current)
        }
        return longest
    }
}

/// 実験の結果
struct ExperimentResult: Equatable, Sendable {
    enum Verdict: Equatable, Sendable {
        /// まだ記録が足りない
        case notEnough
        /// やる日のほうがよい
        case better
        /// やる日のほうがわるい
        case worse
        /// はっきりした差はない
        case noClearDifference
    }

    var doRatings: [Int]
    var restRatings: [Int]
    /// くじのとおりに過ごせなかった日（比べるのから除く）
    var skipped: Int
    var verdict: Verdict
    /// 偶然でこれ以上の差が出る確率（並べ替え検定、両側）
    var pValue: Double?

    var doMean: Double? { Analyzer.mean(doRatings) }
    var restMean: Double? { Analyzer.mean(restRatings) }
    var difference: Double? {
        guard let a = doMean, let b = restMean else { return nil }
        return a - b
    }
}

/// やる日とやすむ日の夜の答えを比べる
enum Analyzer {
    static let minimumPerArm = 3
    /// 意味のある差とみなす平均の差（5 段階で 0.5）
    static let minimumEffect = 0.5
    /// 偶然とは言いにくいとみなす確率
    static let significance = 0.1

    static func result(for experiment: Experiment) -> ExperimentResult {
        var doRatings: [Int] = []
        var restRatings: [Int] = []
        var skipped = 0
        for checkIn in experiment.checkIns.sorted(by: { $0.day < $1.day }) {
            guard let arm = experiment.arm(day: checkIn.day) else { continue }
            guard checkIn.followed else {
                skipped += 1
                continue
            }
            switch arm {
            case .doIt: doRatings.append(checkIn.rating)
            case .rest: restRatings.append(checkIn.rating)
            }
        }
        return result(doRatings: doRatings, restRatings: restRatings, skipped: skipped)
    }

    static func result(doRatings: [Int], restRatings: [Int], skipped: Int = 0) -> ExperimentResult {
        guard doRatings.count >= minimumPerArm, restRatings.count >= minimumPerArm else {
            return ExperimentResult(doRatings: doRatings, restRatings: restRatings, skipped: skipped, verdict: .notEnough, pValue: nil)
        }
        let p = permutationPValue(doRatings, restRatings)
        let difference = (mean(doRatings) ?? 0) - (mean(restRatings) ?? 0)
        let verdict: ExperimentResult.Verdict
        if p <= significance && difference >= minimumEffect {
            verdict = .better
        } else if p <= significance && difference <= -minimumEffect {
            verdict = .worse
        } else {
            verdict = .noClearDifference
        }
        return ExperimentResult(doRatings: doRatings, restRatings: restRatings, skipped: skipped, verdict: verdict, pValue: p)
    }

    static func mean(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// くじの割り付けを入れ替えたすべての組み合わせのうち、今の差以上（絶対値）になる割合。
    /// 実験は最大 14 日なので全部数えられる（14 日で 3,432 通り）。
    static func permutationPValue(_ a: [Int], _ b: [Int]) -> Double {
        let values = a + b
        let n = values.count
        let k = a.count
        guard k > 0, k < n, n <= 24 else { return 1 }
        let total = values.reduce(0, +)
        // 差は sumA だけで決まるので、整数で比べる（丸めの誤差を避ける）
        // diff = sumA/k - (total-sumA)/(n-k) → diff * k * (n-k) = sumA*(n-k) - (total-sumA)*k = sumA*n - total*k
        let observed = abs(a.reduce(0, +) * n - total * k)
        var extreme = 0
        var count = 0
        func walk(_ start: Int, _ chosen: Int, _ sum: Int) {
            if chosen == k {
                count += 1
                if abs(sum * n - total * k) >= observed { extreme += 1 }
                return
            }
            let remaining = k - chosen
            guard start <= n - remaining else { return }
            for i in start...(n - remaining) {
                walk(i + 1, chosen + 1, sum + values[i])
            }
        }
        walk(0, 0, 0)
        return count == 0 ? 1 : Double(extreme) / Double(count)
    }
}

/// くじを入れ替えたときの差の分布（偶然でもこのくらいの差が出る、の図に使う）
struct DifferenceBucket: Equatable, Sendable, Identifiable {
    var difference: Double
    var count: Int
    var id: Double { difference }
}

extension Analyzer {
    /// 記録した点数はそのままに、くじの割り付けだけを全通り入れ替えたときの「平均の差」の分布
    static func differenceDistribution(_ a: [Int], _ b: [Int]) -> [DifferenceBucket] {
        let values = a + b
        let n = values.count
        let k = a.count
        guard k > 0, k < n, n <= 24 else { return [] }
        let total = values.reduce(0, +)
        var counts: [Int: Int] = [:]
        func walk(_ start: Int, _ chosen: Int, _ sum: Int) {
            if chosen == k {
                counts[sum * n - total * k, default: 0] += 1
                return
            }
            let remaining = k - chosen
            guard start <= n - remaining else { return }
            for i in start...(n - remaining) {
                walk(i + 1, chosen + 1, sum + values[i])
            }
        }
        walk(0, 0, 0)
        let scale = Double(k * (n - k))
        return counts.keys.sorted().map { DifferenceBucket(difference: Double($0) / scale, count: counts[$0] ?? 0) }
    }
}

/// 結果を言葉にする
enum ResultText {
    static func headline(_ result: ExperimentResult) -> String {
        switch result.verdict {
        case .notEnough: "まだ分からない"
        case .better: "効いていそう"
        case .worse: "逆効果かも"
        case .noClearDifference: "はっきりした差はない"
        }
    }

    static func symbol(_ result: ExperimentResult) -> String {
        switch result.verdict {
        case .notEnough: "hourglass"
        case .better: "arrow.up.heart.fill"
        case .worse: "arrow.down.heart.fill"
        case .noClearDifference: "equal.circle.fill"
        }
    }

    static func detail(_ result: ExperimentResult) -> String {
        guard result.verdict != .notEnough, let doMean = result.doMean, let restMean = result.restMean,
              let difference = result.difference, let p = result.pValue else {
            return "やる日・やすむ日をそれぞれ \(Analyzer.minimumPerArm) 日以上記録すると、結果が出ます（いま やる日 \(result.doRatings.count) 日・やすむ日 \(result.restRatings.count) 日）。"
        }
        let means = "やる日の平均は \(number(doMean))、やすむ日は \(number(restMean))（差 \(signed(difference))）。"
        let chance = "くじの割り付けを入れ替えても同じくらいの差が出る確率は \(percent(p))。"
        let tail: String
        switch result.verdict {
        case .better: tail = "あなたには効いていると考えてよさそうです。続ける候補に。"
        case .worse: tail = "やらないほうが調子がよいようです。やめるか、やり方を変えてみましょう。"
        default: tail = "差は小さいか、偶然の範囲です。やり方を変えるか、日数を増やして試せます。"
        }
        return means + chance + tail
    }

    static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func signed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded > 0 ? "+" + number(rounded) : number(rounded)
    }

    /// 「偶然でもこのくらいの差が出る確率」のたとえ
    static func analogy(_ p: Double) -> String {
        if p < 0.02 { return "サイコロを 2 回振って、2 回とも 6 が出るより起きにくいくらいです。" }
        if p < 0.06 { return "コインを 5 回投げて、5 回とも表が出るのと同じくらいです。" }
        if p < 0.15 { return "コインを 3 回投げて、3 回とも表が出るのと同じくらいです。" }
        if p < 0.35 { return "コインを 2 回投げて、2 回とも表が出るのと同じくらい。偶然でも起きます。" }
        return "コインの表が出るのと同じくらい、よくあることです。"
    }

    /// あと何日記録すれば結果が出るか
    static func remaining(_ result: ExperimentResult) -> (doDays: Int, restDays: Int) {
        (max(0, Analyzer.minimumPerArm - result.doRatings.count), max(0, Analyzer.minimumPerArm - result.restRatings.count))
    }

    static func percent(_ p: Double) -> String {
        if p < 0.01 { return "1% 未満" }
        return "約 \(Int((p * 100).rounded()))%"
    }
}

/// 続けた日数（どれかの実験で記録した日）。今日まだでも、昨日まで続いていれば数える。
enum Streak {
    static func current(dates: [Date], today: Date, calendar: Calendar) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else {
                return 0
            }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
