import SwiftUI

/// 夜の記録：質問に 1〜5 で答え、くじのとおりに過ごせたかを残す
struct CheckInSheet: View {
    let experiment: Experiment
    let day: Int
    let onSave: (Int, Bool, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var rating: Int?
    @State private var followed = true
    @State private var note = ""
    @State private var saved = false

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(experiment.nextMorning ? "\(day + 1) 日目の翌朝" : "\(day + 1) 日目").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        ArmBadge(arm: arm)
                    }
                    Text(experiment.question)
                        .font(.title.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    ratingPicker

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $followed) {
                            Text(arm == .doIt ? "「\(experiment.action)」をした" : "「\(experiment.action)」をせずに過ごした")
                                .font(.subheadline)
                        }
                        .tint(Theme.color(for: arm))
                        if !followed {
                            Text("くじのとおりにできなかった日は、比べるのから外します。正直に残すほど、結果が確かになります。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .card()

                    TextField("ひとことメモ（なくてよい）", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.05)))

                    Button {
                        guard let rating else { return }
                        onSave(rating, followed, note)
                        saved = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(900))
                            dismiss()
                        }
                    } label: {
                        Label("記録する", systemImage: "checkmark")
                    }
                    .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Theme.color(for: arm))))
                    .disabled(rating == nil || saved)
                }
                .padding(20)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .overlay { if saved { Confetti() } }
            .navigationTitle(experiment.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: rating)
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    private var ratingPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(Array(Experiment.ratingRange), id: \.self) { value in
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.5)) { rating = value }
                    } label: {
                        Text("\(value)")
                            .font(.title.weight(.bold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .foregroundStyle(rating == value ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(rating == value ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.primary.opacity(0.06)))
                            )
                            .scaleEffect(rating == value ? 1.08 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value)")
                    .accessibilityAddTraits(rating == value ? .isSelected : [])
                }
            }
            HStack {
                Text("1 \(experiment.lowLabel)")
                Spacer()
                Text("\(experiment.highLabel) 5")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .card()
    }
}
