import Foundation
import FoundationModels

/// Apple Intelligence の端末の中のモデル（Foundation Models）で、気になることから実験の形を 3 つ考える。
/// 使えるかは SystemLanguageModel.availability で確かめる
/// （https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel）。
/// 出力は guided generation（@Generable）で形を決める
/// （https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation）。
/// 通信はしない。CI のシミュレータでは本物のモデルが動く前提にしない（テストは偽物で書く）。
struct OnDeviceDesigner: ExperimentDesigner {
    var status: DesignerStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            if model.supportsLocale(Locale(identifier: "ja_JP")) {
                return .available
            }
            return .unavailable("Apple Intelligence が日本語に対応していない設定です。組み込みの型から選べます。")
        case .unavailable(.deviceNotEligible):
            return .unavailable("この iPhone は Apple Intelligence に対応していません。組み込みの型から選べます。")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence のモデルを準備中です。それまでは組み込みの型から選べます。")
        case .unavailable:
            return .unavailable("Apple Intelligence が使えません（設定でオフなど）。組み込みの型から選べます。")
        @unknown default:
            return .unavailable("Apple Intelligence が使えません。組み込みの型から選べます。")
        }
    }

    func design(worry: String) async throws -> [ExperimentDraft] {
        let input = String(worry.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !input.isEmpty else { throw DesignError.emptyInput }
        let session = LanguageModelSession(instructions: """
            あなたは、日々の小さな習慣を自分で試す「ひとり実験」を一緒に考える相手です。
            利用者が書いた気になることに対して、14 日間、日ごとにくじで「やる日」と「やすむ日」を決めて比べられる実験を 3 つ考えてください。
            - やることは、1 日で済む、安全で、だれでもできる小さな行動にする（例：寝る前にスマホを置く、昼食後に歩く）。
            - 薬・サプリメント・食事制限・断食・医療に関わることは出さない。
            - 質問は、1〜5 で答えられ、大きいほどよい向きにする。ふつうはその日の夜に答える。
            - 効果が翌朝に分かるもの（寝る前の習慣と、けさの目覚め など）は、翌朝に答える質問にし、answerNextMorning を true にする。
            - すべて自然な日本語で、短く書く。
            """)
        let response = try await session.respond(to: "気になること：\(input)", generating: GeneratedPlans.self)
        let drafts = response.content.plans.map {
            ExperimentDraft(
                title: $0.title, action: $0.action, question: $0.question,
                lowLabel: $0.lowLabel, highLabel: $0.highLabel, reason: $0.reason, source: .model,
                nextMorning: $0.answerNextMorning
            )
        }
        let cleaned = DraftCleaner.cleanAll(drafts)
        guard !cleaned.isEmpty else { throw DesignError.emptyResult }
        return cleaned
    }
}

@Generable
struct GeneratedPlans {
    @Guide(description: "三つの実験の案")
    var plans: [GeneratedPlan]
}

@Generable
struct GeneratedPlan {
    @Guide(description: "実験の短い題（20 文字くらい）")
    var title: String

    @Guide(description: "やる日にする、具体的で小さな行動")
    var action: String

    @Guide(description: "夜に自分に聞く質問。1〜5 で答え、大きいほどよい")
    var question: String

    @Guide(description: "1 のときの様子を表す短い言葉（例：重い）")
    var lowLabel: String

    @Guide(description: "5 のときの様子を表す短い言葉（例：すっきり）")
    var highLabel: String

    @Guide(description: "なぜ効くかもしれないか、一文で")
    var reason: String

    @Guide(description: "効果が翌朝に分かり、質問に翌朝答えるなら true")
    var answerNextMorning: Bool
}
