import SwiftUI

/// いちばん上：続けた日数・記録した日・自分に効くこと
struct SummaryHeader: View {
    let streak: Int
    let recordedDays: Int
    let proven: [Experiment]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                stat(value: "\(streak)", unit: "日", label: "続けて記録", symbol: "flame.fill", color: Theme.amber)
                stat(value: "\(recordedDays)", unit: "日", label: "記録した日", symbol: "calendar", color: Theme.teal)
                stat(value: "\(proven.count)", unit: "個", label: "効くこと", symbol: "checkmark.seal.fill", color: Theme.violet)
            }
            if !proven.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("あなたに効くこと")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(proven) { experiment in
                        Label(experiment.title, systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.violet)
                    }
                }
            }
        }
        .card()
    }

    private func stat(value: String, unit: String, label: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.subheadline)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 進行中の実験の、今日のくじと記録
struct TodayCard: View {
    let experiment: Experiment
    let today: Int?
    let pendingEarlier: Int?
    let onReveal: () -> Void
    let onRecord: (Int) -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(experiment.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let today {
                        Text("\(today + 1) 日目 / \(experiment.duration) 日")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onOpen) {
                    Image(systemName: "chart.bar.xaxis")
                        .accessibilityLabel("結果を見る")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.violet))
            }

            if let today, let arm = experiment.arm(day: today) {
                if experiment.isRevealed(day: today) {
                    revealed(arm: arm, day: today)
                        .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.5, bounce: 0.45)) { onReveal() }
                    } label: {
                        Label("今日のくじを引く", systemImage: "dice.fill")
                    }
                    .buttonStyle(BrandButtonStyle())
                    Text("やる日か、やすむ日か。比べるために、くじで決めます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DayGrid(experiment: experiment, today: today, compact: true)
                .frame(maxWidth: 220)

            if let pendingEarlier {
                Button {
                    onRecord(pendingEarlier)
                } label: {
                    Label("\(pendingEarlier + 1) 日目の分がまだです。記録する", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.rose))
            }
        }
        .card()
    }

    @ViewBuilder
    private func revealed(arm: Arm, day: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日は").font(.title3.weight(.semibold))
                ArmBadge(arm: arm, large: true)
            }
            Text(arm == .doIt ? experiment.action : "いつもどおりに過ごす（「\(experiment.action)」はしない）")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if let checkIn = experiment.checkIn(day: day) {
                HStack {
                    Label("記録しました", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.teal)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(checkIn.rating) / 5").font(.subheadline.monospacedDigit().weight(.bold))
                    Button("直す") { onRecord(day) }
                        .buttonStyle(SoftButtonStyle())
                }
            } else {
                Button {
                    onRecord(day)
                } label: {
                    Label("夜に記録する：\(experiment.question)", systemImage: "moon.stars.fill")
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Theme.color(for: arm))))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.color(for: arm).opacity(0.1)))
    }
}

/// 実験がないとき
struct StartCard: View {
    let onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "flask.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.brand)
            Text("次の実験を始めましょう")
                .font(.title3.weight(.bold))
            Text("気になることを書くと、くじで比べられる 8〜14 日の実験にします。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onNew) {
                Label("実験を作る", systemImage: "plus")
            }
            .buttonStyle(BrandButtonStyle())
        }
        .card()
    }
}

/// 一覧の行（結果の出た実験）
struct ExperimentRow: View {
    let experiment: Experiment

    var body: some View {
        let result = Analyzer.result(for: experiment)
        HStack(spacing: 12) {
            Image(systemName: ResultText.symbol(result))
                .font(.title2)
                .foregroundStyle(color(result))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(experiment.title).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(ResultText.headline(result))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color(result))
                    if let difference = result.difference {
                        Text("差 \(ResultText.signed(difference))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if experiment.isSample {
                        Text("見本").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().strokeBorder(Color.secondary.opacity(0.4)))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func color(_ result: ExperimentResult) -> Color {
        switch result.verdict {
        case .better: Theme.teal
        case .worse: Theme.rose
        case .noClearDifference: Theme.violet
        case .notEnough: .secondary
        }
    }
}
