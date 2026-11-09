import Foundation

/// くじで決まる、その日の過ごし方
enum Arm: String, Codable, Sendable, CaseIterable {
    /// 試すことをする日
    case doIt
    /// いつもどおりに過ごす日（比べる相手）
    case rest

    var title: String { self == .doIt ? "やる日" : "やすむ日" }
}

/// 1 日分の記録（夜に 1 回）
struct CheckIn: Codable, Equatable, Sendable {
    /// 実験の何日目か（0 始まり）
    var day: Int
    /// 夜の質問への答え（1〜5。大きいほどよい）
    var rating: Int
    /// くじのとおりに過ごせたか
    var followed: Bool
    var note: String
    var recordedAt: Date
}

/// ひとつの自分実験。日ごとにくじで「やる日」「やすむ日」を割り付け、夜の答えを比べる。
struct Experiment: Codable, Equatable, Identifiable, Sendable {
    static let ratingRange = 1...5
    static let durations = [8, 14]
    static let defaultDuration = 14
    static let maxTitleLength = 40
    static let maxTextLength = 80
    static let maxNoteLength = 120

    var id = UUID()
    var title: String
    /// やる日にすること
    var action: String
    /// 夜に聞くこと（大きいほどよい向きで聞く）
    var question: String
    var lowLabel: String
    var highLabel: String
    /// なぜ効きそうか
    var reason: String
    /// 1 日目
    var startDate: Date
    var duration: Int
    /// くじの種。同じ種からは同じ割り付けになる
    var seed: UInt64
    var checkIns: [CheckIn] = []
    /// くじを引いた（結果を見た）日
    var revealedDays: [Int] = []
    var endedEarly = false
    var isSample = false
    /// 効果が翌朝に分かる実験（例：寝る前の習慣 → けさの目覚め）。その日の分は翌朝に記録する
    var nextMorning = false
    /// もとにした型（App/Resources/templates.json の id）
    var templateID: String?
    /// 始める前の予想（思い込み）。結果と比べて「予想どおり」「思い込みだった」を出す。古い保存には無いので Optional
    var prediction: Prediction?
    /// 結果発表（けさの開封で、カードを手に入れる場面）を見たか。古い保存には無いので Optional
    var announced: Bool?

    /// 記録が何日ずれるか（翌朝に記録する実験は 1）
    var recordLag: Int { nextMorning ? 1 : 0 }

    var schedule: [Arm] { Scheduler.schedule(days: duration, seed: seed) }

    func dayIndex(on date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
    }

    func date(ofDay day: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: startDate)) ?? startDate
    }

    func arm(day: Int) -> Arm? {
        let schedule = schedule
        return schedule.indices.contains(day) ? schedule[day] : nil
    }

    func checkIn(day: Int) -> CheckIn? {
        checkIns.first { $0.day == day }
    }

    func isRevealed(day: Int) -> Bool {
        revealedDays.contains(day) || checkIn(day: day) != nil
    }

    /// 終わったか（期間が過ぎた・全部の日を記録した・途中でやめた）
    func isFinished(on date: Date, calendar: Calendar) -> Bool {
        endedEarly || dayIndex(on: date, calendar: calendar) >= duration + recordLag || Set(checkIns.map(\.day)).count >= duration
    }

    /// 今日が何日目か（期間の外なら nil）
    func today(on date: Date, calendar: Calendar) -> Int? {
        let index = dayIndex(on: date, calendar: calendar)
        return (0..<duration).contains(index) ? index : nil
    }

    /// まだ記録していない、記録できる日（期間の中。翌朝に記録する実験は昨日まで）。新しい順
    func pendingDays(on date: Date, calendar: Calendar) -> [Int] {
        guard !endedEarly else { return [] }
        let last = min(dayIndex(on: date, calendar: calendar) - recordLag, duration - 1)
        guard last >= 0 else { return [] }
        let recorded = Set(checkIns.map(\.day))
        return (0...last).reversed().filter { !recorded.contains($0) }
    }
}

/// 始める前の予想
enum Prediction: String, Codable, Sendable, CaseIterable, Identifiable {
    case works, unsure, doesNotWork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .works: "きっと効く"
        case .unsure: "半信半疑"
        case .doesNotWork: "効かないと思う"
        }
    }

    var symbol: String {
        switch self {
        case .works: "hand.thumbsup"
        case .unsure: "questionmark"
        case .doesNotWork: "hand.thumbsdown"
        }
    }
}

/// 実験の下書き（Apple Intelligence・組み込みの型・自分で書いたもの）
struct ExperimentDraft: Equatable, Identifiable, Sendable {
    enum Source: String, Sendable { case model, template, manual }

    var id = UUID()
    var title: String
    var action: String
    var question: String
    var lowLabel: String
    var highLabel: String
    var reason: String
    var source: Source
    var nextMorning = false
    var templateID: String?

    static func == (lhs: ExperimentDraft, rhs: ExperimentDraft) -> Bool {
        lhs.title == rhs.title && lhs.action == rhs.action && lhs.question == rhs.question
            && lhs.lowLabel == rhs.lowLabel && lhs.highLabel == rhs.highLabel && lhs.reason == rhs.reason && lhs.source == rhs.source
            && lhs.nextMorning == rhs.nextMorning && lhs.templateID == rhs.templateID
    }

    static let empty = ExperimentDraft(title: "", action: "", question: "", lowLabel: "", highLabel: "", reason: "", source: .manual)
}

/// 下書きを整える（空・長すぎ・医療に当たるものを除く）
enum DraftCleaner {
    /// 医療・服薬・極端な食事に当たる言葉。日々の小さな習慣だけを扱う
    static let blockedWords = [
        "薬", "サプリ", "断食", "絶食", "処方", "治療", "注射", "ダイエット", "食事制限", "カロリー", "糖質",
        "medication", "supplement", "fasting", "drug", "diet",
    ]

    static func clean(_ draft: ExperimentDraft) -> ExperimentDraft? {
        var result = draft
        result.title = trim(draft.title, max: Experiment.maxTitleLength)
        result.action = trim(draft.action, max: Experiment.maxTextLength)
        result.question = trim(draft.question, max: Experiment.maxTextLength)
        result.lowLabel = trim(draft.lowLabel, max: 12)
        result.highLabel = trim(draft.highLabel, max: 12)
        result.reason = trim(draft.reason, max: Experiment.maxTextLength * 2)
        if result.lowLabel.isEmpty { result.lowLabel = "わるい" }
        if result.highLabel.isEmpty { result.highLabel = "よい" }
        guard !result.title.isEmpty, !result.action.isEmpty, !result.question.isEmpty else { return nil }
        let text = [result.title, result.action, result.question, result.reason].joined(separator: " ").lowercased()
        guard !blockedWords.contains(where: { text.contains($0) }) else { return nil }
        return result
    }

    /// 重複（同じ題）を除いて整える
    static func cleanAll(_ drafts: [ExperimentDraft], limit: Int = 3) -> [ExperimentDraft] {
        var seen: Set<String> = []
        var result: [ExperimentDraft] = []
        for draft in drafts {
            guard let cleaned = clean(draft), seen.insert(cleaned.title).inserted else { continue }
            result.append(cleaned)
            if result.count == limit { break }
        }
        return result
    }

    static func trim(_ text: String, max: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max))
    }
}
