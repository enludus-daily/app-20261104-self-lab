import Foundation
import Observation

/// 実験の保存（端末の UserDefaults だけ。PrivacyInfo.xcprivacy に CA92.1 で申告済み）
@MainActor
@Observable
final class ExperimentStore {
    private(set) var experiments: [Experiment] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String
    @ObservationIgnored let calendar: Calendar

    init(defaults: UserDefaults = .standard, key: String = "experiments.v1", seedSamples: Bool = true, now: Date = .now, calendar: Calendar = .current) {
        self.defaults = defaults
        self.key = key
        self.calendar = calendar
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Experiment].self, from: data) {
            experiments = saved
        } else if seedSamples {
            // 初めて開いたときだけ見本を置く（全部消したあとは置かない）
            experiments = Samples.experiments(now: now, calendar: calendar)
            save()
        }
    }

    func experiment(id: UUID) -> Experiment? {
        experiments.first { $0.id == id }
    }

    func active(now: Date = .now) -> [Experiment] {
        experiments.filter { !$0.isFinished(on: now, calendar: calendar) && $0.dayIndex(on: now, calendar: calendar) >= 0 }
            .sorted { $0.startDate > $1.startDate }
    }

    func finished(now: Date = .now) -> [Experiment] {
        experiments.filter { $0.isFinished(on: now, calendar: calendar) }
            .sorted { $0.date(ofDay: $0.duration, calendar: calendar) > $1.date(ofDay: $1.duration, calendar: calendar) }
    }

    /// 新しい実験を、今日を 1 日目として始める
    @discardableResult
    func start(_ draft: ExperimentDraft, duration: Int = Experiment.defaultDuration, now: Date = .now, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) -> UUID? {
        guard let cleaned = DraftCleaner.clean(draft) else { return nil }
        let experiment = Experiment(
            title: cleaned.title, action: cleaned.action, question: cleaned.question,
            lowLabel: cleaned.lowLabel, highLabel: cleaned.highLabel, reason: cleaned.reason,
            startDate: calendar.startOfDay(for: now),
            duration: Experiment.durations.contains(duration) ? duration : Experiment.defaultDuration,
            seed: seed,
            nextMorning: cleaned.nextMorning,
            templateID: cleaned.templateID
        )
        experiments.append(experiment)
        save()
        return experiment.id
    }

    /// くじを引く（その日の割り付けを見せる）
    func reveal(id: UUID, day: Int) {
        guard let index = experiments.firstIndex(where: { $0.id == id }),
              (0..<experiments[index].duration).contains(day),
              !experiments[index].revealedDays.contains(day) else { return }
        experiments[index].revealedDays.append(day)
        save()
    }

    /// 夜の記録。同じ日は上書きする。まだ来ていない日・期間の外は受け付けない
    @discardableResult
    func record(id: UUID, day: Int, rating: Int, followed: Bool, note: String = "", now: Date = .now) -> Bool {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return false }
        let experiment = experiments[index]
        guard (0..<experiment.duration).contains(day), day <= experiment.dayIndex(on: now, calendar: calendar) - experiment.recordLag,
              Experiment.ratingRange.contains(rating), !experiment.endedEarly else { return false }
        let checkIn = CheckIn(
            day: day, rating: rating, followed: followed,
            note: DraftCleaner.trim(note, max: Experiment.maxNoteLength), recordedAt: now
        )
        experiments[index].checkIns.removeAll { $0.day == day }
        experiments[index].checkIns.append(checkIn)
        if !experiments[index].revealedDays.contains(day) { experiments[index].revealedDays.append(day) }
        save()
        return true
    }

    /// 同じ実験を、今日からもう一度（新しいくじで）始める
    @discardableResult
    func restart(id: UUID, now: Date = .now, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) -> UUID? {
        guard let old = experiment(id: id) else { return nil }
        let draft = ExperimentDraft(
            title: old.title, action: old.action, question: old.question, lowLabel: old.lowLabel, highLabel: old.highLabel,
            reason: old.reason, source: .manual, nextMorning: old.nextMorning, templateID: old.templateID
        )
        return start(draft, duration: old.duration, now: now, seed: seed)
    }

    func endEarly(id: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return }
        experiments[index].endedEarly = true
        save()
    }

    func delete(id: UUID) {
        experiments.removeAll { $0.id == id }
        save()
    }

    /// 記録した日（翌朝に記録する実験は、その翌日）
    var recordedDates: [Date] {
        experiments.flatMap { experiment in
            experiment.checkIns.map { experiment.date(ofDay: $0.day + experiment.recordLag, calendar: calendar) }
        }
    }

    func streak(now: Date = .now) -> Int {
        Streak.current(dates: recordedDates, today: now, calendar: calendar)
    }

    var recordedDayCount: Int {
        Set(recordedDates.map { calendar.startOfDay(for: $0) }).count
    }

    /// 結果が「効いていそう」になった実験（自分に効くことの一覧）
    func provenHabits(now: Date = .now) -> [Experiment] {
        finished(now: now).filter { Analyzer.result(for: $0).verdict == .better }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(experiments) {
            defaults.set(data, forKey: key)
        }
    }
}

/// 初めて開いたときの見本：結果の出た実験・途中でやめた実験・進行中（記録の抜けあり）の実験
enum Samples {
    static let finishedSeed: UInt64 = 20_261_104
    static let endedSeed: UInt64 = 5_551_104
    static let activeSeed: UInt64 = 7_771_104

    private static func base(_ id: String, start: Date, duration: Int, seed: UInt64) -> Experiment? {
        guard let t = TemplateLibrary.template(id: id) else { return nil }
        return Experiment(
            title: t.title, action: t.action, question: t.question, lowLabel: t.lowLabel, highLabel: t.highLabel,
            reason: t.reason, startDate: start, duration: duration, seed: seed, isSample: true,
            nextMorning: t.nextMorning, templateID: t.id
        )
    }

    static func experiments(now: Date, calendar: Calendar) -> [Experiment] {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }
        var result: [Experiment] = []

        // 1. 結果の出た実験（寝る前にスマホを置く → 効果あり）
        if var finished = base("sleep-phone-away", start: day(-30), duration: 14, seed: finishedSeed) {
            let doValues = [4, 5, 4, 4, 3, 5, 4]
            let restValues = [3, 2, 3, 2, 4, 3, 2]
            var doIndex = 0
            var restIndex = 0
            for (d, arm) in finished.schedule.enumerated() {
                let rating: Int
                switch arm {
                case .doIt:
                    rating = doValues[doIndex % doValues.count]
                    doIndex += 1
                case .rest:
                    rating = restValues[restIndex % restValues.count]
                    restIndex += 1
                }
                let recordedAt = calendar.date(byAdding: .hour, value: 31, to: finished.date(ofDay: d, calendar: calendar)) ?? today
                finished.checkIns.append(CheckIn(day: d, rating: rating, followed: d != 9, note: "", recordedAt: recordedAt))
                finished.revealedDays.append(d)
            }
            result.append(finished)
        }

        // 2. 途中でやめた実験（白黒表示 → 6 日でやめた）
        if var ended = base("digital-grayscale", start: day(-14), duration: 14, seed: endedSeed) {
            for d in 0..<6 {
                let rating = ended.arm(day: d) == .doIt ? 3 : 3
                let recordedAt = calendar.date(byAdding: .hour, value: 22, to: ended.date(ofDay: d, calendar: calendar)) ?? today
                ended.checkIns.append(CheckIn(day: d, rating: rating + (d % 2), followed: true, note: "", recordedAt: recordedAt))
                ended.revealedDays.append(d)
            }
            ended.endedEarly = true
            result.append(ended)
        }

        // 3. 進行中（昼食のあと歩く）：4 日目。2 日目の記録が抜けている。今日のくじはまだ
        if var active = base("focus-lunch-walk", start: day(-3), duration: 14, seed: activeSeed) {
            for d in [0, 2] {
                let rating = active.arm(day: d) == .doIt ? 4 : 2
                let recordedAt = calendar.date(byAdding: .hour, value: 22, to: active.date(ofDay: d, calendar: calendar)) ?? today
                active.checkIns.append(CheckIn(day: d, rating: rating, followed: true, note: "", recordedAt: recordedAt))
            }
            active.revealedDays = [0, 1, 2]
            result.append(active)
        }
        return result
    }
}
