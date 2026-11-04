import Foundation

enum DesignerStatus: Equatable, Sendable {
    case available
    /// 使えない理由（画面に出す）
    case unavailable(String)
}

enum DesignError: Error, Equatable {
    case emptyInput
    case emptyResult
}

/// 気になることから実験の形を考える役。本物は端末の中のモデル（OnDeviceDesigner）、テストでは偽物に差し替える。
protocol ExperimentDesigner: Sendable {
    var status: DesignerStatus { get }
    func design(worry: String) async throws -> [ExperimentDraft]
}

/// モデルを使わない（使えない）ときの役
struct UnavailableDesigner: ExperimentDesigner {
    var reason: String
    var status: DesignerStatus { .unavailable(reason) }

    func design(worry: String) async throws -> [ExperimentDraft] {
        throw DesignError.emptyResult
    }
}

/// 組み込みの実験の型。Apple Intelligence が使えないときも、これで始められる。
struct ExperimentTemplate: Sendable {
    var title: String
    var action: String
    var question: String
    var lowLabel: String
    var highLabel: String
    var reason: String
    var symbol: String
    var keywords: [String]
    var nextMorning = false

    var draft: ExperimentDraft {
        ExperimentDraft(
            title: title, action: action, question: question, lowLabel: lowLabel, highLabel: highLabel,
            reason: reason, source: .template, nextMorning: nextMorning
        )
    }
}

enum TemplateLibrary {
    static let all: [ExperimentTemplate] = [
        ExperimentTemplate(
            title: "寝る 1 時間前にスマホを置く", action: "寝る 1 時間前にスマホを別の部屋に置く",
            question: "けさの目覚めはどうだった？", lowLabel: "重い", highLabel: "すっきり",
            reason: "画面と通知から離れると、寝る前に頭が静まりやすいと言われます。自分にも当てはまるか確かめます。",
            symbol: "iphone.slash", keywords: ["眠", "寝", "朝", "目覚め", "スマホ", "夜更かし", "起き"],
            nextMorning: true
        ),
        ExperimentTemplate(
            title: "午後 2 時からコーヒーをやめる", action: "午後 2 時を過ぎたらコーヒー・緑茶・エナジードリンクを飲まない",
            question: "ゆうべの寝つきはどうだった？", lowLabel: "なかなか", highLabel: "すぐ眠れた",
            reason: "カフェインは数時間残ります。午後に飲む量が、自分の寝つきに響いているかを見ます。",
            symbol: "cup.and.saucer", keywords: ["寝つき", "眠れ", "コーヒー", "カフェイン", "夜", "寝"],
            nextMorning: true
        ),
        ExperimentTemplate(
            title: "朝 5 分、外の光を浴びる", action: "起きて 1 時間以内に 5 分、外に出るか窓辺に立つ",
            question: "きょうの日中のシャキッと感は？", lowLabel: "ぼんやり", highLabel: "シャキッと",
            reason: "朝の光は体内時計を合わせる手がかりと言われます。日中の調子が変わるかを見ます。",
            symbol: "sun.max", keywords: ["朝", "だるい", "眠い", "ぼんやり", "日中", "起き"]
        ),
        ExperimentTemplate(
            title: "昼食のあと 10 分歩く", action: "昼食を食べ終えたら 10 分歩く",
            question: "きょうの午後の集中は？", lowLabel: "途切れた", highLabel: "続いた",
            reason: "食後に軽く体を動かすと、午後の眠気が変わる人がいます。あなたはどうかを確かめます。",
            symbol: "figure.walk", keywords: ["午後", "眠い", "集中", "昼", "眠気", "だるい"]
        ),
        ExperimentTemplate(
            title: "仕事の前に「今日の 3 つ」を書く", action: "始める前に、今日いちばん大事なことを 3 つ紙に書く",
            question: "きょうの手応えは？", lowLabel: "流された", highLabel: "進んだ",
            reason: "先に決めておくと、迷う時間が減るかもしれません。手応えが変わるかを見ます。",
            symbol: "list.number", keywords: ["仕事", "やる気", "先延ばし", "手応え", "進まない", "勉強"]
        ),
        ExperimentTemplate(
            title: "通知を切って 90 分作業する", action: "午前に 90 分、通知をすべて切って作業する",
            question: "きょうの集中は？", lowLabel: "散った", highLabel: "深かった",
            reason: "通知のたびに注意が途切れます。まとまった時間を作ると集中が変わるかを見ます。",
            symbol: "bell.slash", keywords: ["通知", "集中", "気が散", "スマホ", "作業", "仕事"]
        ),
        ExperimentTemplate(
            title: "寝る前に「よかったこと 3 つ」", action: "寝る前に、その日よかったことを 3 つ書く",
            question: "寝る前の気分は？", lowLabel: "もやもや", highLabel: "おだやか",
            reason: "よかったことに目を向ける習慣が、自分の気分に効くかを確かめます。",
            symbol: "sparkles", keywords: ["気分", "もやもや", "落ち込", "不安", "イライラ", "寝る前"]
        ),
        ExperimentTemplate(
            title: "朝は SNS を開かない", action: "起きてから昼まで SNS のアプリを開かない",
            question: "きょうの午前の気分は？", lowLabel: "ざわざわ", highLabel: "落ち着いた",
            reason: "朝いちばんの情報が一日の気分を決めているかもしれません。開かない日と比べます。",
            symbol: "bubble.left.and.exclamationmark.bubble.right", keywords: ["SNS", "sns", "朝", "気分", "スマホ", "比べ"]
        ),
        ExperimentTemplate(
            title: "20 分以内の昼寝", action: "昼に 20 分以内の昼寝をする（タイマーをかける）",
            question: "きょうの夕方の元気は？", lowLabel: "ぐったり", highLabel: "元気",
            reason: "短い昼寝で午後が楽になる人と、かえってだるくなる人がいます。どちらかを確かめます。",
            symbol: "powersleep", keywords: ["昼寝", "午後", "眠", "疲れ", "夕方", "元気"]
        ),
        ExperimentTemplate(
            title: "25 分ずつ区切って進める", action: "作業を 25 分ずつ区切り、間に 5 分休む",
            question: "きょうのはかどりは？", lowLabel: "進まない", highLabel: "はかどった",
            reason: "区切りがあると始めやすくなる人がいます。いつものやり方と比べます。",
            symbol: "timer", keywords: ["勉強", "作業", "はかど", "先延ばし", "集中", "宿題"]
        ),
        ExperimentTemplate(
            title: "夕方 10 分の片付け", action: "夕方に 10 分だけ、部屋を片付ける",
            question: "夜、部屋でくつろげた？", lowLabel: "落ち着かない", highLabel: "くつろげた",
            reason: "散らかった部屋が気持ちに響いているかを確かめます。",
            symbol: "sparkles.rectangle.stack", keywords: ["部屋", "片付", "散らか", "くつろ", "家"]
        ),
        ExperimentTemplate(
            title: "帰り道にひと駅歩く", action: "帰りにひと駅（15 分ほど）歩く",
            question: "夜の気分は？", lowLabel: "どんより", highLabel: "すっきり",
            reason: "仕事と家の間に区切りを作ると、夜の気分が変わるかもしれません。",
            symbol: "figure.walk.motion", keywords: ["帰り", "仕事", "夜", "気分", "運動", "ストレス"]
        ),
    ]

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

    static func symbol(for title: String) -> String {
        all.first { $0.title == title }?.symbol ?? "flask"
    }
}
