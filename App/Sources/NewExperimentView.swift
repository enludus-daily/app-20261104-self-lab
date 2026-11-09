import SwiftUI

/// Pro の型のお試し（Pro でなくても 1 つだけ使える）。端末の UserDefaults に型の id を 1 つだけ残す
enum TrialState {
    static let key = "proTrialTemplate"

    static var templateID: String? { UserDefaults.standard.string(forKey: key) }

    static func use(_ id: String) {
        guard templateID == nil else { return }
        UserDefaults.standard.set(id, forKey: key)
    }
}

/// 実験を作る画面を、気になること・分類・型を入れた状態で開く
struct NewExperimentSeed: Identifiable {
    let id = UUID()
    var worry = ""
    var category: TemplateCategory?
    var template: ExperimentTemplate?
}

/// 実験を作る：66 の型（無料 42・Pro 24）から選ぶのが主。気になることを書くと合う型を探す。
/// Apple Intelligence は使える端末でだけ、脇に「案をもらう」を出す（使えなくても何も欠けない）。
struct NewExperimentView: View {
    let designer: any ExperimentDesigner
    let seed: NewExperimentSeed

    @Environment(ExperimentStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var worry = ""
    @State private var suggestions: [ExperimentDraft] = []
    @State private var category: TemplateCategory?
    @State private var expanded: String?
    @State private var editing: EditingDraft?
    @State private var isThinking = false
    @State private var notice: String?
    @State private var paywall: PaywallReason?
    @State private var prepared = false

    var body: some View {
        let isPro = purchases.isPro
        let canStart = ProGate.canStartAnother(activeCount: store.activeOwnCount(), isPro: isPro)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    if !canStart {
                        limitBanner(isPro: isPro)
                    }
                    searchPanel
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            SectionTitle(text: "合いそうな実験")
                            ForEach(suggestions) { suggestion in
                                SuggestionRow(draft: suggestion, template: TemplateLibrary.template(id: suggestion.templateID)) {
                                    choose(draft: suggestion, template: TemplateLibrary.template(id: suggestion.templateID))
                                }
                            }
                        }
                    }
                    catalog(isPro: isPro)
                    Text("医療・服薬・食事制限に関わる実験は扱いません。体調に関わることは医師に相談してください。")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(Space.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("新しい実験")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("自分で書く") {
                        editing = EditingDraft(draft: .empty, days: Experiment.defaultDuration)
                    }
                }
            }
            .navigationDestination(item: $editing) { item in
                DraftEditor(initial: item.draft, days: item.days) { draft, days, prediction in
                    attemptStart(draft, days: days, prediction: prediction)
                }
            }
            .sheet(item: $paywall) { reason in
                PaywallView(reason: reason)
            }
        }
        .onAppear {
            guard !prepared else { return }
            prepared = true
            worry = seed.worry
            category = seed.category
            if !seed.worry.isEmpty { suggestions = TemplateLibrary.suggestions(for: seed.worry) }
            if let template = seed.template { choose(draft: template.draft, template: template) }
        }
    }

    private func limitBanner(isPro: Bool) -> some View {
        Panel(padding: Space.m) {
            VStack(alignment: .leading, spacing: Space.s) {
                Label(isPro ? "同時に進められるのは \(ProGate.proActiveLimit) つまでです" : "無料では、同時に進める実験は \(ProGate.freeActiveLimit) つまで", systemImage: "info.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.ink)
                Text(isPro ? "進行中の実験が終わるか、途中で終えると始められます。" : "いまの実験が終わるのを待つか、Pro で 3 つまで同時に進められます。")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if !isPro {
                    Button { paywall = .moreExperiments } label: { Label("Pro を見る", systemImage: "sparkles") }
                        .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                }
            }
        }
    }

    private var searchPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("気になること・ためしたいこと")
                    .font(Typo.title(.headline))
                    .foregroundStyle(Palette.ink)
                TextField("例：午後になると眠くて集中できない", text: $worry, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(Space.m)
                    .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.field))
                    .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
                HStack(spacing: Space.m) {
                    Button(action: search) {
                        Label("合う型を探す", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedWorry.isEmpty)
                    if designer.status == .available {
                        Button(action: askModel) {
                            if isThinking {
                                ProgressView()
                            } else {
                                Label("AI の案", systemImage: "apple.intelligence")
                            }
                        }
                        .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                        .disabled(trimmedWorry.isEmpty || isThinking)
                        .accessibilityLabel("Apple Intelligence に案をもらう")
                    }
                }
                if let notice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var trimmedWorry: String {
        worry.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func catalog(isPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionTitle(text: "\(TemplateLibrary.all.count) の型から選ぶ", detail: "無料 \(TemplateLibrary.freeCount) · Pro \(TemplateLibrary.proCount)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    chip(nil, title: "すべて", symbol: "square.grid.2x2")
                    ForEach(TemplateCategory.allCases) { item in
                        chip(item, title: item.title, symbol: item.symbol)
                    }
                }
                .padding(.vertical, 2)
            }
            ForEach(TemplateLibrary.templates(in: category)) { template in
                TemplateRow(
                    template: template,
                    expanded: expanded == template.id,
                    locked: !ProGate.canUse(template, isPro: isPro, trialTemplateID: TrialState.templateID),
                    trial: template.isPro && !isPro && TrialState.templateID == nil
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        expanded = expanded == template.id ? nil : template.id
                    }
                } onChoose: {
                    choose(draft: template.draft, template: template)
                }
            }
        }
    }

    private func chip(_ item: TemplateCategory?, title: String, symbol: String) -> some View {
        let selected = category == item
        return Button {
            withAnimation(.snappy) { category = item }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Palette.sky.deep : Palette.ink)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 40)
                .background(Capsule().fill(selected ? Palette.sky.soft : Palette.card))
                .overlay(Capsule().strokeBorder(selected ? Palette.sky.accent : Palette.line, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func choose(draft: ExperimentDraft, template: ExperimentTemplate?) {
        if let template, !ProGate.canUse(template, isPro: purchases.isPro, trialTemplateID: TrialState.templateID) {
            paywall = .proTemplate
            return
        }
        editing = EditingDraft(draft: draft, days: template?.days ?? Experiment.defaultDuration)
    }

    private func attemptStart(_ draft: ExperimentDraft, days: Int, prediction: Prediction?) {
        guard ProGate.canStartAnother(activeCount: store.activeOwnCount(), isPro: purchases.isPro) else {
            paywall = purchases.isPro ? nil : .moreExperiments
            return
        }
        if let template = TemplateLibrary.template(id: draft.templateID), template.isPro, !purchases.isPro {
            TrialState.use(template.id)
        }
        store.start(draft, duration: days, prediction: prediction)
        dismiss()
    }

    private func search() {
        let text = trimmedWorry
        guard !text.isEmpty else { return }
        notice = nil
        withAnimation(.snappy) { suggestions = TemplateLibrary.suggestions(for: text) }
    }

    private func askModel() {
        let text = trimmedWorry
        guard !text.isEmpty else { return }
        isThinking = true
        Task {
            do {
                let result = try await designer.design(worry: text)
                notice = "Apple Intelligence（端末の中）の案です。直してから始められます。"
                withAnimation(.snappy) { suggestions = result }
            } catch {
                notice = "案を作れませんでした。合いそうな型を出しています。"
                withAnimation(.snappy) { suggestions = TemplateLibrary.suggestions(for: text) }
            }
            isThinking = false
        }
    }
}

struct EditingDraft: Identifiable, Hashable {
    let id = UUID()
    var draft: ExperimentDraft
    var days: Int

    static func == (lhs: EditingDraft, rhs: EditingDraft) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 案の 1 行
struct SuggestionRow: View {
    let draft: ExperimentDraft
    let template: ExperimentTemplate?
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            HStack(spacing: Space.m) {
                Image(systemName: template?.symbol ?? (draft.source == .model ? "apple.intelligence" : "testtube.2"))
                    .foregroundStyle(Palette.sky.deep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Palette.sky.soft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(draft.question)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if template?.isPro == true {
                    TagText(text: "Pro", color: Palette.sky.deep)
                }
                Image(systemName: "chevron.right").foregroundStyle(Palette.inkSoft)
            }
            .padding(Space.m)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }
}

/// 型の 1 行（押すと開いて、なぜ・コツ・落とし穴）
struct TemplateRow: View {
    let template: ExperimentTemplate
    let expanded: Bool
    let locked: Bool
    let trial: Bool
    let onToggle: () -> Void
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Button(action: onToggle) {
                HStack(spacing: Space.m) {
                    Image(systemName: template.symbol)
                        .font(.body.weight(.light))
                        .foregroundStyle(Palette.sky.deep)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Palette.sky.soft))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        TagText(text: "\(template.category.title) · \(template.days) 日\(template.nextMorning ? " · 翌朝に記録" : "")")
                    }
                    Spacer(minLength: 0)
                    if template.isPro {
                        Text(locked ? "Pro" : (trial ? "お試し可" : "Pro"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.sky.deep)
                            .padding(.horizontal, Space.s)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Palette.sky.soft))
                    }
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(Palette.inkSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(template.reason).font(.footnote).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(template.tip, systemImage: "lightbulb").font(.footnote).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(template.pitfall, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onChoose) {
                        Label(locked ? "Pro で使う" : "これにする", systemImage: locked ? "lock" : "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .transition(.opacity)
            }
        }
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
    }
}

/// 実験の形を直して始める。始める前に「効くと思う？」の予想を残す（結果のカードで答え合わせ）
struct DraftEditor: View {
    @State private var draft: ExperimentDraft
    @State private var days: Int
    @State private var prediction: Prediction = .unsure
    @State private var problem: String?
    let onStart: (ExperimentDraft, Int, Prediction?) -> Void

    init(initial: ExperimentDraft, days: Int, onStart: @escaping (ExperimentDraft, Int, Prediction?) -> Void) {
        _draft = State(initialValue: initial)
        _days = State(initialValue: Experiment.durations.contains(days) ? days : Experiment.defaultDuration)
        self.onStart = onStart
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Panel {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text(draft.title.isEmpty ? "新しい実験" : draft.title)
                            .font(Typo.title(.title3))
                            .foregroundStyle(Palette.ink)
                        field("題", text: $draft.title, prompt: "例：昼食のあと 10 分歩く")
                        field("やる日にすること", text: $draft.action, prompt: "例：昼食を食べ終えたら 10 分歩く")
                        field("自分に聞くこと（大きいほどよい）", text: $draft.question, prompt: "例：きょうの午後の集中は？")
                        HStack(spacing: Space.m) {
                            field("1 のとき", text: $draft.lowLabel, prompt: "わるい")
                            field("5 のとき", text: $draft.highLabel, prompt: "よい")
                        }
                        Toggle("効果は翌朝に分かる（翌朝に記録する）", isOn: $draft.nextMorning)
                            .font(.subheadline)
                            .tint(Palette.sky.deep)
                        Picker("日数", selection: $days) {
                            ForEach(Experiment.durations, id: \.self) { value in
                                Text(value == 14 ? "\(value) 日（しっかり）" : "\(value) 日（短め）").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text("始める前に、予想を 1 つ")
                            .font(Typo.title(.headline))
                            .foregroundStyle(Palette.ink)
                        Text("結果のカードで答え合わせをします。思い込みがひっくり返ると「思い込みを破った」の印が付きます。")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Picker("予想", selection: $prediction) {
                            ForEach(Prediction.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Text("毎朝カードをめくると、その日が「やる日」か「やすむ日」かが出ます（半分ずつ、順番はくじ）。結果は最後の日まで伏せておきます。")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.peach.deep)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Button(action: start) {
                    Label("きょうから始める", systemImage: "testtube.2")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Space.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("実験の形")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start() {
        if let cleaned = DraftCleaner.clean(draft) {
            onStart(cleaned, days, prediction)
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            problem = DraftProblem.message(for: draft)
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            TagText(text: title)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...3)
                .padding(Space.m)
                .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.field))
                .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
        }
    }
}

/// 下書きが使えない理由（次の一歩の一文）
enum DraftProblem {
    static func message(for draft: ExperimentDraft) -> String {
        let trimmed = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if trimmed(draft.title).isEmpty { return "題を書いてください（例：昼食のあと 10 分歩く）。" }
        if trimmed(draft.action).isEmpty { return "やる日にすることを書いてください。" }
        if trimmed(draft.question).isEmpty { return "毎日自分に聞くことを書いてください（例：きょうの午後の集中は？）。" }
        return "医療・服薬・食事制限に関わる実験は扱いません。生活の小さな習慣で試してみましょう。"
    }
}
