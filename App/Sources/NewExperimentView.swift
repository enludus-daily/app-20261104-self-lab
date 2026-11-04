import SwiftUI

/// 実験を作る：気になることを書く → 案（Apple Intelligence か組み込みの型）を選ぶ → 直して始める
struct NewExperimentView: View {
    let designer: any ExperimentDesigner
    let onStart: (ExperimentDraft, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var worry: String
    @State private var suggestions: [ExperimentDraft]
    @State private var draft: ExperimentDraft?
    @State private var duration = Experiment.defaultDuration
    @State private var isThinking = false
    @State private var notice: String?

    init(designer: any ExperimentDesigner, seed: NewExperimentSeed?, onStart: @escaping (ExperimentDraft, Int) -> Void) {
        self.designer = designer
        self.onStart = onStart
        _worry = State(initialValue: seed?.worry ?? "")
        _suggestions = State(initialValue: seed?.suggestions ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    worryCard
                    if let notice {
                        Label(notice, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !suggestions.isEmpty {
                        Text("実験の案").font(.headline)
                        ForEach(suggestions) { suggestion in
                            SuggestionCard(draft: suggestion, selected: draft?.title == suggestion.title) {
                                withAnimation(.snappy) { draft = suggestion }
                            }
                        }
                    }
                    if let draft {
                        editor(for: draft)
                            .id(draft.id)
                    }
                    templateStrip
                    Text("医療の判断には使わないでください。体調に関わることは医師に相談してください。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("実験を作る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var worryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("気になること・ためしたいこと")
                .font(.headline)
            TextField("例：午後になると眠くて集中できない", text: $worry, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.05)))
            Button(action: think) {
                if isThinking {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("考えています…")
                    }
                } else {
                    Label(designer.status == .available ? "Apple Intelligence で実験を考える" : "合う実験の型を探す", systemImage: designer.status == .available ? "apple.intelligence" : "magnifyingglass")
                }
            }
            .buttonStyle(BrandButtonStyle())
            .disabled(worry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            if case .unavailable(let reason) = designer.status {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var templateStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("型から選ぶ").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TemplateLibrary.all, id: \.title) { template in
                        Button {
                            withAnimation(.snappy) { draft = template.draft }
                        } label: {
                            Label(template.title, systemImage: template.symbol)
                        }
                        .buttonStyle(SoftButtonStyle(tint: Theme.violet))
                    }
                }
            }
            Button {
                withAnimation(.snappy) { draft = ExperimentDraft.empty }
            } label: {
                Label("自分で書く", systemImage: "square.and.pencil")
            }
            .buttonStyle(SoftButtonStyle())
        }
    }

    private func editor(for initial: ExperimentDraft) -> some View {
        DraftEditor(initial: initial, duration: $duration) { edited in
            onStart(edited, duration)
            dismiss()
        }
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

/// 案のカード
struct SuggestionCard: View {
    let draft: ExperimentDraft
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: draft.source == .model ? "apple.intelligence" : TemplateLibrary.symbol(for: draft.title))
                        .foregroundStyle(Theme.brand)
                    Text(draft.title).font(.headline).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.teal : .secondary)
                }
                Label(draft.action, systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.teal)
                Label(draft.question, systemImage: "moon.stars.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.violet)
                if !draft.reason.isEmpty {
                    Text(draft.reason).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
            }
            .foregroundStyle(.primary)
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(selected ? Theme.teal : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 選んだ案を直して始める
struct DraftEditor: View {
    @State private var draft: ExperimentDraft
    @Binding var duration: Int
    let onStart: (ExperimentDraft) -> Void

    init(initial: ExperimentDraft, duration: Binding<Int>, onStart: @escaping (ExperimentDraft) -> Void) {
        _draft = State(initialValue: initial)
        _duration = duration
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("この形で始める").font(.headline)
            field("題", text: $draft.title, prompt: "例：昼食のあと 10 分歩く")
            field("やる日にすること", text: $draft.action, prompt: "例：昼食を食べ終えたら 10 分歩く")
            field("夜に聞くこと（大きいほどよい）", text: $draft.question, prompt: "例：きょうの午後の集中は？")
            HStack {
                field("1 のとき", text: $draft.lowLabel, prompt: "わるい")
                field("5 のとき", text: $draft.highLabel, prompt: "よい")
            }
            Picker("日数", selection: $duration) {
                ForEach(Experiment.durations, id: \.self) { days in
                    Text(days == 14 ? "\(days) 日（しっかり）" : "\(days) 日（短め）").tag(days)
                }
            }
            .pickerStyle(.segmented)
            Text("毎日くじで、やる日とやすむ日を半分ずつ決めます。くじは当日まで秘密です。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                onStart(draft)
            } label: {
                Label("今日から始める", systemImage: "flask.fill")
            }
            .buttonStyle(BrandButtonStyle())
            .disabled(DraftCleaner.clean(draft) == nil)
        }
        .card()
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...3)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        }
    }
}
