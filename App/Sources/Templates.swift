import Foundation

/// 実験の型の分類
enum TemplateCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case sleep, morning, focus, mood, move, digital, home

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: "睡眠"
        case .morning: "朝の過ごし方"
        case .focus: "集中"
        case .mood: "気分"
        case .move: "体を動かす"
        case .digital: "デジタル習慣"
        case .home: "暮らし"
        }
    }

    var symbol: String {
        switch self {
        case .sleep: "moon.zzz"
        case .morning: "sunrise"
        case .focus: "scope"
        case .mood: "face.smiling"
        case .move: "figure.walk"
        case .digital: "iphone"
        case .home: "house"
        }
    }
}

/// 組み込みの実験の型（App/Resources/templates.json）。Apple Intelligence が使えないときも、これで始められる。
struct ExperimentTemplate: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var category: TemplateCategory
    var title: String
    var action: String
    var question: String
    var lowLabel: String
    var highLabel: String
    var reason: String
    /// 続けるコツ
    var tip: String
    /// よくある落とし穴
    var pitfall: String
    /// おすすめの日数（8 か 14）
    var days: Int
    var nextMorning: Bool
    var symbol: String
    var keywords: [String]

    var draft: ExperimentDraft {
        ExperimentDraft(
            title: title, action: action, question: question, lowLabel: lowLabel, highLabel: highLabel,
            reason: reason, source: .template, nextMorning: nextMorning, templateID: id
        )
    }
}

/// この型のある束（アプリ）を見つけるための目印
final class TemplateBundleToken {}

enum TemplateLibrary {
    /// 型の一覧（読み込めなければ空。テストで件数を確かめる）
    static let all: [ExperimentTemplate] = load()

    static func load(bundle: Bundle = Bundle(for: TemplateBundleToken.self)) -> [ExperimentTemplate] {
        guard let url = bundle.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let templates = try? JSONDecoder().decode([ExperimentTemplate].self, from: data) else { return [] }
        return templates
    }

    static func template(id: String?) -> ExperimentTemplate? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func templates(in category: TemplateCategory?) -> [ExperimentTemplate] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// 気になることに合う型を、当てはまる言葉が多い順に返す（無ければ最初の数個）
    static func suggestions(for worry: String, limit: Int = 3) -> [ExperimentDraft] {
        let text = worry.lowercased()
        let scored = all.enumerated().map { index, template in
            (index: index, template: template, score: template.keywords.filter { text.contains($0.lowercased()) }.count)
        }
        let matched = scored.filter { $0.score > 0 }.sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        let picked = matched.isEmpty ? Array(scored.prefix(limit)) : Array(matched.prefix(limit))
        return picked.map(\.template.draft)
    }

    static func symbol(for experiment: Experiment) -> String {
        template(id: experiment.templateID)?.symbol ?? all.first { $0.title == experiment.title }?.symbol ?? "flask"
    }
}
