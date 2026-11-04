import Charts
import SwiftUI

/// 実験の中身：日ごとのマス目と、やる日・やすむ日の比べた結果。
/// 広い画面（iPhone Duo の内側など。horizontal size class が regular）では、マス目と結果を横に並べる。
struct ExperimentDetailView: View {
    let experimentID: UUID
    let onRecord: (Int) -> Void
    let onDeleted: () -> Void
    let onNext: () -> Void

    @Environment(ExperimentStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var confirmingEnd = false
    @State private var confirmingDelete = false

    var body: some View {
        if let experiment = store.experiment(id: experimentID) {
            let now = Date.now
            let finished = experiment.isFinished(on: now, calendar: store.calendar)
            let today = finished ? nil : experiment.today(on: now, calendar: store.calendar)
            let result = Analyzer.result(for: experiment)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(experiment)
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            gridCard(experiment, today: today)
                            resultCard(experiment, result: result, finished: finished)
                        }
                    } else {
                        resultCard(experiment, result: result, finished: finished)
                        gridCard(experiment, today: today)
                    }
                    actions(experiment, finished: finished, today: today)
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle(experiment.isSample ? "見本の実験" : "実験")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("この実験を途中で終えますか？", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("終えて結果を見る") { store.endEarly(id: experiment.id) }
            } message: {
                Text("ここまでの記録で結果を出します。")
            }
            .confirmationDialog("この実験を消しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("消す", role: .destructive) {
                    store.delete(id: experiment.id)
                    onDeleted()
                }
            }
        }
    }

    private func header(_ experiment: Experiment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: TemplateLibrary.symbol(for: experiment.title))
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.brand))
                VStack(alignment: .leading, spacing: 2) {
                    Text(experiment.title).font(.title2.weight(.bold))
                    Text("\(experiment.startDate.formatted(.dateTime.month().day())) から \(experiment.duration) 日")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Label(experiment.action, systemImage: "bolt.fill").foregroundStyle(Theme.teal)
            Label(experiment.question + (experiment.nextMorning ? "（翌朝に記録）" : ""), systemImage: experiment.nextMorning ? "sunrise.fill" : "moon.stars.fill")
                .foregroundStyle(Theme.violet)
            if !experiment.reason.isEmpty {
                Text(experiment.reason).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .card()
    }

    private func gridCard(_ experiment: Experiment, today: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日ごとの記録").font(.headline)
            DayGrid(experiment: experiment, today: today)
            HStack(spacing: 14) {
                legend(color: Theme.teal, text: "やる日")
                legend(color: Theme.violet, text: "やすむ日")
                legend(color: Theme.amber, text: "今日", outline: true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("数字は夜の答え（1〜5）。薄い色は、くじのとおりにできなかった日。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func legend(color: Color, text: String, outline: Bool = false) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(outline ? Color.clear : color)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(outline ? color : Color.clear, lineWidth: 2))
                .frame(width: 12, height: 12)
            Text(text)
        }
    }

    private func resultCard(_ experiment: Experiment, result: ExperimentResult, finished: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(finished ? "結果" : "途中の結果").font(.headline)
                Spacer()
                if result.skipped > 0 {
                    Text("除いた日 \(result.skipped)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Label(ResultText.headline(result), systemImage: ResultText.symbol(result))
                .font(.title.weight(.heavy))
                .foregroundStyle(verdictColor(result))
            if result.doMean != nil || result.restMean != nil {
                Chart {
                    ForEach(Arm.allCases, id: \.self) { arm in
                        let ratings = arm == .doIt ? result.doRatings : result.restRatings
                        if let mean = Analyzer.mean(ratings) {
                            BarMark(x: .value("日", arm.title), y: .value("平均", mean), width: .ratio(0.5))
                                .foregroundStyle(Theme.color(for: arm).opacity(0.85))
                                .cornerRadius(8)
                                .annotation(position: .top) {
                                    Text(ResultText.number(mean)).font(.caption.weight(.bold).monospacedDigit())
                                }
                        }
                        ForEach(Array(ratings.enumerated()), id: \.offset) { index, rating in
                            PointMark(x: .value("日", arm.title), y: .value("答え", Double(rating) + jitter(index)))
                                .foregroundStyle(Theme.color(for: arm))
                                .symbolSize(30)
                                .opacity(0.55)
                        }
                    }
                }
                .chartYScale(domain: 0...5.6)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5])
                }
                .frame(height: 200)
                .accessibilityLabel("やる日とやすむ日の平均の比較")
            }
            Text(ResultText.detail(result))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func recordLabel(_ experiment: Experiment, day: Int, today: Int?) -> String {
        if experiment.nextMorning, let today, day == today - 1 { return "けさの記録をする" }
        if day == today { return "今日の分を記録する" }
        return "\(day + 1) 日目の分を記録する"
    }

    /// 同じ値の点が重ならないよう、少しずらす
    private func jitter(_ index: Int) -> Double {
        Double((index % 5) - 2) * 0.06
    }

    private func verdictColor(_ result: ExperimentResult) -> Color {
        switch result.verdict {
        case .better: Theme.teal
        case .worse: Theme.rose
        case .noClearDifference: Theme.violet
        case .notEnough: .secondary
        }
    }

    @ViewBuilder
    private func actions(_ experiment: Experiment, finished: Bool, today: Int?) -> some View {
        VStack(spacing: 10) {
            if !finished, let day = experiment.pendingDays(on: .now, calendar: store.calendar).first {
                Button {
                    onRecord(day)
                } label: {
                    Label(recordLabel(experiment, day: day, today: today), systemImage: experiment.nextMorning ? "sunrise.fill" : "moon.stars.fill")
                }
                .buttonStyle(BrandButtonStyle())
            }
            if finished {
                Button(action: onNext) {
                    Label("次の実験を作る", systemImage: "plus")
                }
                .buttonStyle(BrandButtonStyle())
            }
            HStack {
                if !finished {
                    Button("途中で終える") { confirmingEnd = true }
                        .buttonStyle(SoftButtonStyle(tint: Theme.violet))
                }
                Spacer()
                Button("消す", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(SoftButtonStyle(tint: Theme.rose))
            }
            Text("医療の判断には使わないでください。体調に関わることは医師に相談してください。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
