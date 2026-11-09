import SwiftUI

/// 記録：質問に 1〜5 で答える。選んだ数字を細い輪が囲み、くじのとおりにできたかを残す
struct CheckInSheet: View {
    let experiment: Experiment
    let day: Int
    let onSave: (Int, Bool, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rating: Int?
    @State private var followed = true
    @State private var note = ""
    @State private var saved = false
    @State private var failures = 0

    init(experiment: Experiment, day: Int, onSave: @escaping (Int, Bool, String) -> Void) {
        self.experiment = experiment
        self.day = day
        self.onSave = onSave
        let existing = experiment.checkIn(day: day)
        _rating = State(initialValue: existing?.rating)
        _followed = State(initialValue: existing?.followed ?? true)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        let arm = experiment.arm(day: day) ?? .doIt
        let swatch = Palette.swatch(for: arm)
        NavigationStack {
            ScrollView {
                Panel {
                    VStack(alignment: .leading, spacing: Space.l) {
                        HStack(spacing: Space.s) {
                            TagText(text: experiment.nextMorning ? "\(day + 1) 日目の翌朝" : "\(day + 1) 日目の夜", color: Palette.ink)
                            Text(arm.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(swatch.deep)
                                .padding(.horizontal, Space.s)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: Radius.tag).fill(swatch.soft))
                        }
                        Text(experiment.question)
                            .font(Typo.title(.title))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        ratingRow(swatch: swatch)

                        HStack {
                            Text("1 \(experiment.lowLabel)")
                            Spacer()
                            Text("\(experiment.highLabel) 5")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.inkSoft)

                        Toggle(isOn: $followed) {
                            Text(arm == .doIt ? "「\(experiment.action)」をした" : "「\(experiment.action)」をせずに過ごした")
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                        }
                        .tint(swatch.deep)
                        if !followed {
                            Text("くじのとおりにできなかった日は、輪だけの点になり、比べるのから外します。正直に残すほど結果が確かになります。")
                                .font(.caption)
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        TextField("ひとことメモ（なくてよい）", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(Space.m)
                            .background(Palette.field)
                            .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(Palette.line, lineWidth: 0.6))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))

                        if rating == nil && failures > 0 {
                            Text("先に 1〜5 のどれかに丸をつけてください。")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.peach.deep)
                        }

                        Button(action: save) {
                            Label(saved ? "記録しました" : "記録する", systemImage: saved ? "checkmark" : "pencil")
                        }
                        .buttonStyle(PrimaryButtonStyle(swatch: swatch))
                        .disabled(saved)
                    }
                }
                .padding(Space.l)
                .padding(.top, Space.l)
            }
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle(experiment.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .haptic(.selection, trigger: rating)
            .haptic(.success, trigger: saved)
        }
    }

    private func ratingRow(swatch: Swatch) -> some View {
        HStack(spacing: Space.s) {
            ForEach(Array(Experiment.ratingRange), id: \.self) { value in
                let selected = rating == value
                Button {
                    if reduceMotion {
                        rating = value
                    } else {
                        withAnimation(.easeOut(duration: 0.35)) { rating = value }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(swatch.soft.opacity(selected ? 1 : 0))
                        Text("\(value)")
                            .font(.system(.title, design: .serif).weight(.regular).monospacedDigit())
                            .foregroundStyle(selected ? swatch.deep : Palette.ink)
                        // 選んだ数字を、細い輪がなぞって囲む（trim で描く）
                        Ellipse()
                            .trim(from: 0, to: selected ? 1 : 0)
                            .stroke(swatch.deep, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                            .rotationEffect(.degrees(-100))
                            .scaleEffect(x: 1.05, y: 0.9)
                            .padding(4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func save() {
        guard let rating else {
            withAnimation(.easeOut(duration: 0.25)) { failures += 1 }
            return
        }
        onSave(rating, followed, note)
        saved = true
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 1000))
            dismiss()
        }
    }
}
