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
            nextMorning: cleaned.nextMorning
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

/// 初めて開いたときの見本。結果の出た実験と、進行中の実験を 1 つずつ
enum Samples {
    static let finishedSeed: UInt64 = 20_261_104
    static let activeSeed: UInt64 = 7_771_104

    static func experiments(now: Date, calendar: Calendar) -> [Experiment] {
        let today = calendar.startOfDay(for: now)
        let phone = TemplateLibrary.all[0]
        var finished = Experiment(
            title: phone.title, action: phone.action, question: phone.question,
            lowLabel: phone.lowLabel, highLabel: phone.highLabel, reason: phone.reason,
            startDate: calendar.date(byAdding: .day, value: -18, to: today) ?? today,
            duration: 14, seed: finishedSeed, isSample: true, nextMorning: phone.nextMorning
        )
        let doValues = [4, 5, 4, 4, 3, 5, 4]
        let restValues = [3, 2, 3, 2, 4, 3, 2]
        var doIndex = 0
        var restIndex = 0
        for (day, arm) in finished.schedule.enumerated() {
            let rating: Int
            switch arm {
            case .doIt:
                rating = doValues[doIndex % doValues.count]
                doIndex += 1
            case .rest:
                rating = restValues[restIndex % restValues.count]
                restIndex += 1
            }
            // 1 日だけ、くじのとおりにできなかった日を入れる
            let followed = day != 9
            let recordedAt = calendar.date(byAdding: .hour, value: 31, to: finished.date(ofDay: day, calendar: calendar)) ?? today
            finished.checkIns.append(CheckIn(day: day, rating: rating, followed: followed, note: "", recordedAt: recordedAt))
            finished.revealedDays.append(day)
        }

        let coffee = TemplateLibrary.all[1]
        var active = Experiment(
            title: coffee.title, action: coffee.action, question: coffee.question,
            lowLabel: coffee.lowLabel, highLabel: coffee.highLabel, reason: coffee.reason,
            startDate: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
            duration: 14, seed: activeSeed, isSample: true, nextMorning: coffee.nextMorning
        )
        // 3 日目までくじを引き、2 日目までの朝に記録した。3 日目の分（けさの記録）と、今日のくじが残っている
        for day in 0..<3 {
            active.revealedDays.append(day)
        }
        for day in 0..<2 {
            let rating = active.arm(day: day) == .doIt ? 4 : 3
            let recordedAt = calendar.date(byAdding: .hour, value: 31, to: active.date(ofDay: day, calendar: calendar)) ?? today
            active.checkIns.append(CheckIn(day: day, rating: rating, followed: true, note: "", recordedAt: recordedAt))
        }
        return [finished, active]
    }
}
