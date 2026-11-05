import SwiftUI

/// 実験を作る：気になることを書く（Apple Intelligence か型から案）／42 の型を分類から選ぶ → 直して始める
struct NewExperimentView: View {
    let designer: any ExperimentDesigner
    let onStart: (ExperimentDraft, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var worry: String
    @State private var suggestions: [ExperimentDraft]
    @State private var category: TemplateCategory?
    @State private var expanded: String?
    @State private var editing: EditingDraft?
    @State private var isThinking = false
    @State private var notice: String?

    init(designer: any ExperimentDesigner, seed: NewExperimentSeed, onStart: @escaping (ExperimentDraft, Int) -> Void) {
        self.designer = designer
        self.onStart = onStart
        _worry = State(initialValue: seed.worry)
        _suggestions = State(initialValue: seed.suggestions)
        _category = State(initialValue: seed.category)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    worryPage
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionTitle(text: "あなたへの案", symbol: "sparkles")
                            ForEach(suggestions) { suggestion in
                                SuggestionStrip(draft: suggestion, template: TemplateLibrary.template(id: suggestion.templateID)) {
                                    editing = EditingDraft(draft: suggestion, days: TemplateLibrary.template(id: suggestion.templateID)?.days ?? Experiment.defaultDuration)
                                }
                            }
                        }
                    }
                    catalog
                    Text("医療・服薬・食事制限に関わる実験は扱いません。体調に関わることは医師に相談してください。")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(Space.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.desk.ignoresSafeArea())
            .navigationTitle("実験を作る")
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
                DraftEditor(initial: item.draft, days: item.days) { draft, days in
                    onStart(draft, days)
                    dismiss()
                }
            }
        }
    }

    private var worryPage: some View {
        NotebookPage {
            VStack(alignment: .leading, spacing: Space.m) {
                PageTitle(text: "気になること・ためしたいこと", font: Typo.title(.headline))
                TextField("例：午後になると眠くて集中できない", text: $worry, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(Space.m)
                    .background(Palette.label)
                    .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(Palette.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                Button(action: think) {
                    if isThinking {
                        HStack(spacing: Space.s) {
                            ProgressView().tint(.white)
                            Text("考えています…")
                        }
                    } else {
                        Label(designer.status == .available ? "Apple Intelligence で実験を考える" : "合う実験の型を探す",
                              systemImage: designer.status == .available ? "apple.intelligence" : "magnifyingglass")
                    }
                }
                .buttonStyle(StampButtonStyle())
                .disabled(worry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
                if case .unavailable(let reason) = designer.status {
                    Label(reason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let notice {
                    Label(notice, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(Palette.peach.deep)
                }
            }
        }
        .padding(.top, Space.m)
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionTitle(text: "\(TemplateLibrary.all.count) の型から選ぶ", symbol: "tray.full")
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
                TemplateStrip(template: template, expanded: expanded == template.id) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        expanded = expanded == template.id ? nil : template.id
                    }
                } onChoose: {
                    editing = EditingDraft(draft: template.draft, days: template.days)
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
                .background(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(selected ? Palette.sky.soft : Palette.label))
                .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(selected ? Palette.sky.accent : Palette.line, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func think() {
        let text = worry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard designer.status == .available else {
            notice = nil
            withAnimation(.snappy) { suggestions = TemplateLibrary.suggestions(for: text) }
            return
        }
        isThinking = true
        Task {
            do {
                let result = try await designer.design(worry: text)
                notice = nil
                withAnimation(.snappy) { suggestions = result }
            } catch {
                notice = "Apple Intelligence で案を作れませんでした。合いそうな型を出しています。"
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

/// 案の紙片
struct SuggestionStrip: View {
    let draft: ExperimentDraft
    let template: ExperimentTemplate?
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    Image(systemName: draft.source == .model ? "apple.intelligence" : (template?.symbol ?? "flask"))
                        .foregroundStyle(Palette.sky.deep)
                    Text(draft.title).font(Typo.title(.headline)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Palette.inkSoft)
                }
                Label(draft.action, systemImage: "bolt").font(.subheadline).foregroundStyle(Palette.peach.deep)
                Label(draft.question + (draft.nextMorning ? "（翌朝）" : ""), systemImage: draft.nextMorning ? "sunrise" : "moon.stars")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sky.deep)
            }
            .multilineTextAlignment(.leading)
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }
}

/// 型の紙片。押すと、なぜ・コツ・落とし穴が開く
struct TemplateStrip: View {
    let template: ExperimentTemplate
    let expanded: Bool
    let onToggle: () -> Void
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: Space.m) {
                    Image(systemName: template.symbol)
                        .font(.title3)
                        .foregroundStyle(Palette.sky.deep)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(template.title).font(Typo.title(.subheadline)).foregroundStyle(Palette.ink)
                        Text(template.question).font(.caption).foregroundStyle(Palette.inkSoft)
                        HStack(spacing: Space.s) {
                            TagText(text: "\(template.days) 日", color: Palette.ink)
                            TagText(text: template.nextMorning ? "翌朝に記録" : "夜に記録", color: Palette.ink)
                            TagText(text: template.category.title)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Palette.inkSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "閉じる" : "なぜ・コツ・落とし穴を開く")
            if expanded {
                VStack(alignment: .leading, spacing: Space.s) {
                    Label(template.action, systemImage: "bolt").foregroundStyle(Palette.peach.deep)
                    Text(template.reason).foregroundStyle(Palette.ink)
                    Label(template.tip, systemImage: "lightbulb").foregroundStyle(Palette.ink)
                    Label(template.pitfall, systemImage: "exclamationmark.triangle").foregroundStyle(Palette.peach.deep)
                    Button(action: onChoose) {
                        Label("この実験にする", systemImage: "flask")
                    }
                    .buttonStyle(StampButtonStyle())
                }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Space.m)
        .background(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
    }
}

/// 選んだ案を直して始める
struct DraftEditor: View {
    @State private var draft: ExperimentDraft
    @State private var days: Int
    @State private var failures = 0
    @State private var problem: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onStart: (ExperimentDraft, Int) -> Void

    init(initial: ExperimentDraft, days: Int, onStart: @escaping (ExperimentDraft, Int) -> Void) {
        _draft = State(initialValue: initial)
        _days = State(initialValue: Experiment.durations.contains(days) ? days : Experiment.defaultDuration)
        self.onStart = onStart
    }

    var body: some View {
        ScrollView {
            NotebookPage {
                VStack(alignment: .leading, spacing: Space.m) {
                    PageTitle(text: draft.title.isEmpty ? "新しい実験" : draft.title)
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
                    Text("毎日くじで、やる日とやすむ日を半分ずつ決めます。くじは当日まで秘密です。")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                    if let problem {
                        Text(problem)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.peach.deep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(action: start) {
                        Label("今日から始める", systemImage: "flask.fill")
                    }
                    .buttonStyle(StampButtonStyle())
                }
            }
            .padding(Space.l)
            .padding(.top, Space.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.desk.ignoresSafeArea())
        .navigationTitle("実験の形")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start() {
        if let cleaned = DraftCleaner.clean(draft) {
            onStart(cleaned, days)
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            problem = DraftProblem.message(for: draft)
            failures += 1
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            TagText(text: title)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...3)
                .padding(Space.s)
                .background(Palette.label)
                .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(Palette.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
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
