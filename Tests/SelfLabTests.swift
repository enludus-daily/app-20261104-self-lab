import Foundation
import Testing
@testable import SelfLab

private var tokyo: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}

private func day(_ d: Int, hour: Int = 12) -> Date {
    tokyo.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
}

private func draft(_ title: String = "昼食のあと歩く") -> ExperimentDraft {
    ExperimentDraft(title: title, action: "10 分歩く", question: "午後の集中は？", lowLabel: "", highLabel: "", reason: "", source: .manual)
}

@MainActor
private func makeStore(seedSamples: Bool = false, now: Date = day(4)) -> ExperimentStore {
    let name = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return ExperimentStore(defaults: defaults, key: "experiments", seedSamples: seedSamples, now: now, calendar: tokyo)
}

// MARK: - くじの割り付け

struct SchedulerTests {
    @Test func sameSeedGivesSameSchedule() {
        #expect(Scheduler.schedule(days: 14, seed: 99) == Scheduler.schedule(days: 14, seed: 99))
    }

    @Test func knownSeedIsStable() {
        // 保存しているのは種だけなので、OS が変わっても割り付けが変わらないこと
        let expected: [Arm] = "DDRDDRRRDRDRRD".map { $0 == "D" ? .doIt : .rest }
        #expect(Scheduler.schedule(days: 14, seed: 20_261_104) == expected)
    }

    @Test(arguments: [8, 14], [UInt64(1), 2, 3, 42, 20_261_104, UInt64.max])
    func halfAndHalfWithoutLongRuns(days: Int, seed: UInt64) {
        let schedule = Scheduler.schedule(days: days, seed: seed)
        #expect(schedule.count == days)
        #expect(schedule.filter { $0 == .doIt }.count == days / 2)
        #expect(Scheduler.longestRun(schedule) <= Scheduler.maxRun)
    }

    @Test func differentSeedsDiffer() {
        let schedules = Set((1...20).map { Scheduler.schedule(days: 14, seed: UInt64($0)).map(\.rawValue).joined() })
        #expect(schedules.count > 10)
    }

    @Test func longestRun() {
        #expect(Scheduler.longestRun([]) == 0)
        #expect(Scheduler.longestRun([.doIt, .doIt, .rest, .rest, .rest, .doIt]) == 3)
    }
}

// MARK: - 結果

struct AnalyzerTests {
    @Test func needsThreeDaysEach() {
        let result = Analyzer.result(doRatings: [5, 5], restRatings: [1, 1, 1])
        #expect(result.verdict == .notEnough)
        #expect(result.pValue == nil)
        #expect(ResultText.detail(result).contains("やる日 2 日"))
    }

    @Test func clearImprovementIsBetter() {
        let result = Analyzer.result(doRatings: [4, 5, 4, 5], restRatings: [2, 3, 2, 3])
        #expect(result.verdict == .better)
        #expect(abs((result.pValue ?? 1) - 2.0 / 70.0) < 1e-9)
        #expect(result.difference == 2)
    }

    @Test func clearDropIsWorse() {
        let result = Analyzer.result(doRatings: [1, 2, 1, 2], restRatings: [4, 4, 5, 4])
        #expect(result.verdict == .worse)
    }

    @Test func sameValuesHaveNoDifference() {
        let result = Analyzer.result(doRatings: [3, 3, 3], restRatings: [3, 3, 3])
        #expect(result.verdict == .noClearDifference)
        #expect(result.pValue == 1)
    }

    @Test func smallDifferenceIsNotCalledAnEffect() {
        // 偶然とは言いにくくても、差が 0.5 未満なら「効いた」とは言わない
        let result = Analyzer.result(doRatings: [3, 3, 3, 3, 3, 3, 4], restRatings: [3, 3, 3, 3, 3, 3, 3])
        #expect(result.verdict == .noClearDifference)
    }

    @Test func permutationPValue() {
        #expect(abs(Analyzer.permutationPValue([5, 5, 5], [1, 1, 1]) - 0.1) < 1e-9)
        #expect(Analyzer.permutationPValue([1, 2, 3], [3, 2, 1]) == 1)
        #expect(Analyzer.permutationPValue([], [1, 2]) == 1)
    }

    @Test func skipsDaysNotFollowed() {
        var experiment = Experiment(
            title: "t", action: "a", question: "q", lowLabel: "l", highLabel: "h", reason: "",
            startDate: day(1), duration: 8, seed: 42
        )
        for (index, arm) in experiment.schedule.enumerated() {
            experiment.checkIns.append(CheckIn(day: index, rating: arm == .doIt ? 5 : 2, followed: index != 0, note: "", recordedAt: day(1)))
        }
        let result = Analyzer.result(for: experiment)
        #expect(result.skipped == 1)
        #expect(result.doRatings.count + result.restRatings.count == 7)
    }

    @Test func textMentionsMeansAndChance() {
        let result = Analyzer.result(doRatings: [4, 5, 4, 5], restRatings: [2, 3, 2, 3])
        let text = ResultText.detail(result)
        #expect(text.contains("4.5"))
        #expect(text.contains("+2.0"))
        #expect(text.contains("約 3%"))
        #expect(ResultText.headline(result) == "効いていそう")
        #expect(ResultText.percent(0.001) == "1% 未満")
    }
}

// MARK: - 偶然の確率の図・言葉

struct ChanceTests {
    @Test func distributionCoversAllCombinations() {
        let buckets = Analyzer.differenceDistribution([4, 5, 4, 5], [2, 3, 2, 3])
        #expect(buckets.reduce(0) { $0 + $1.count } == 70)
        #expect(buckets.map(\.difference) == buckets.map(\.difference).sorted())
        // 外側の割合が p 値と同じ
        let outside = buckets.filter { abs($0.difference) >= 2 - 1e-9 }.reduce(0) { $0 + $1.count }
        #expect(abs(Double(outside) / 70 - Analyzer.permutationPValue([4, 5, 4, 5], [2, 3, 2, 3])) < 1e-9)
    }

    @Test func distributionIsSymmetricForEqualGroups() {
        let buckets = Analyzer.differenceDistribution([1, 2, 3], [4, 5, 6])
        let dict = Dictionary(uniqueKeysWithValues: buckets.map { ($0.difference, $0.count) })
        for (d, c) in dict {
            #expect(dict[-d] == c)
        }
    }

    @Test func analogyGetsRarerWithSmallerP() {
        #expect(ResultText.analogy(0.01).contains("サイコロ"))
        #expect(ResultText.analogy(0.03).contains("5 回"))
        #expect(ResultText.analogy(0.5).contains("よくある"))
    }

    @Test func remainingDays() {
        let result = Analyzer.result(doRatings: [3], restRatings: [3, 3])
        let left = ResultText.remaining(result)
        #expect(left.doDays == 2)
        #expect(left.restDays == 1)
    }
}

// MARK: - 画面の文

@MainActor
struct WordingTests {
    @Test func greetingNeverBlames() {
        #expect(Greeting.text(streak: 0, recordedDays: 0).contains("ようこそ"))
        #expect(Greeting.text(streak: 0, recordedDays: 9).contains("おかえり"))
        #expect(Greeting.text(streak: 5, recordedDays: 9).contains("5 日続けて"))
        for streak in 0...3 {
            let text = Greeting.text(streak: streak, recordedDays: 4)
            #expect(!text.contains("途切れ"))
        }
    }

    @Test func statusGivesNextStep() {
        var e = Experiment(title: "t", action: "a", question: "q", lowLabel: "l", highLabel: "h", reason: "", startDate: day(1), duration: 8, seed: 1)
        let empty = Analyzer.result(for: e)
        #expect(DetailText.status(experiment: e, finished: false, today: 0, result: empty, now: day(1), calendar: tokyo).contains("あと やる日"))
        #expect(DetailText.status(experiment: e, finished: false, today: 3, result: empty, now: day(4), calendar: tokyo).contains("抜けている"))
        e.endedEarly = true
        #expect(DetailText.status(experiment: e, finished: true, today: nil, result: empty, now: day(4), calendar: tokyo).contains("途中で終えた"))
    }

    @Test func labNotesAreManyAndStable() {
        #expect(LabNotes.all.count >= 30)
        #expect(Set(LabNotes.all).count == LabNotes.all.count)
        #expect(LabNotes.note(seed: 42, day: 3) == LabNotes.note(seed: 42, day: 3))
        let notes = Set((0..<14).map { LabNotes.note(seed: 42, day: $0) })
        #expect(notes.count > 5)
    }

    @Test func ratingTiersIncrease() {
        let tiers = (1...5).map(Palette.ratingOpacity)
        #expect(tiers == tiers.sorted())
        #expect(Palette.ratingOpacity(9) == 1)
    }
}

// MARK: - 実験の日付

struct ExperimentDayTests {
    private func experiment(start: Date = day(1)) -> Experiment {
        Experiment(title: "t", action: "a", question: "q", lowLabel: "l", highLabel: "h", reason: "", startDate: start, duration: 8, seed: 1)
    }

    @Test func dayIndexFollowsCalendarDays() {
        let e = experiment(start: day(1, hour: 23))
        #expect(e.dayIndex(on: day(1, hour: 1), calendar: tokyo) == 0)
        #expect(e.dayIndex(on: day(2, hour: 0), calendar: tokyo) == 1)
        #expect(e.today(on: day(8), calendar: tokyo) == 7)
        #expect(e.today(on: day(9), calendar: tokyo) == nil)
        #expect(e.isFinished(on: day(9), calendar: tokyo))
        #expect(!e.isFinished(on: day(8), calendar: tokyo))
    }

    @Test func pendingDaysAreUnrecordedPastDaysNewestFirst() {
        var e = experiment()
        e.checkIns = [CheckIn(day: 1, rating: 3, followed: true, note: "", recordedAt: day(2))]
        #expect(e.pendingDays(on: day(4), calendar: tokyo) == [3, 2, 0])
        #expect(e.pendingDays(on: day(20), calendar: tokyo).first == 7)
    }

    @Test func nextMorningRecordsTheDayAfter() {
        var e = experiment()
        e.nextMorning = true
        #expect(e.pendingDays(on: day(1), calendar: tokyo).isEmpty)
        #expect(e.pendingDays(on: day(2), calendar: tokyo) == [0])
        // 最後の日の分は、期間の次の朝に記録する
        #expect(!e.isFinished(on: day(9), calendar: tokyo))
        #expect(e.pendingDays(on: day(9), calendar: tokyo).first == 7)
        #expect(e.isFinished(on: day(10), calendar: tokyo))
    }

    @Test func futureDaysStayHidden() {
        let e = experiment()
        #expect(!e.isRevealed(day: 3))
    }
}

// MARK: - 下書きと型

struct DraftTests {
    @Test func fillsDefaultLabelsAndTrims() {
        let cleaned = DraftCleaner.clean(ExperimentDraft(title: "  歩く  ", action: "歩く", question: "どう？", lowLabel: " ", highLabel: "", reason: "", source: .manual))
        #expect(cleaned?.title == "歩く")
        #expect(cleaned?.lowLabel == "わるい")
        #expect(cleaned?.highLabel == "よい")
    }

    @Test func rejectsEmptyAndMedical() {
        #expect(DraftCleaner.clean(.empty) == nil)
        #expect(DraftCleaner.clean(ExperimentDraft(title: "サプリを飲む", action: "朝に飲む", question: "調子は？", lowLabel: "", highLabel: "", reason: "", source: .model)) == nil)
    }

    @Test func cleanAllRemovesDuplicatesAndLimits() {
        let drafts = [draft("A"), draft("A"), draft("B"), draft("C"), draft("D")]
        #expect(DraftCleaner.cleanAll(drafts).map(\.title) == ["A", "B", "C"])
    }

    @Test func templatesMatchWorry() {
        let titles = TemplateLibrary.suggestions(for: "午後になると眠くて集中できない").map(\.title)
        #expect(titles.first == "昼食のあと 10 分歩く")
        #expect(titles.count == 3)
    }

    @Test func templatesFallBackWhenNothingMatches() {
        #expect(TemplateLibrary.suggestions(for: "zzz").count == 3)
    }

    @Test func draftProblemExplainsNextStep() {
        #expect(DraftProblem.message(for: .empty).contains("題"))
        var draft = draft("サプリを飲む")
        draft.action = "朝に飲む"
        #expect(DraftCleaner.clean(draft) == nil)
        #expect(DraftProblem.message(for: draft).contains("医療"))
    }
}

// MARK: - 実験の型（App/Resources/templates.json）

struct TemplateLibraryTests {
    @Test func hasAtLeastFortyTemplates() {
        #expect(TemplateLibrary.all.count >= 40)
        #expect(TemplateLibrary.freeCount == 42)
        #expect(TemplateLibrary.proCount == 24)
        let proTemplates = TemplateLibrary.all.filter { $0.isPro }
        #expect(proTemplates.allSatisfy { $0.category == .study || $0.category == .people })
    }

    @Test func idsAreUnique() {
        #expect(Set(TemplateLibrary.all.map(\.id)).count == TemplateLibrary.all.count)
        #expect(Set(TemplateLibrary.all.map(\.title)).count == TemplateLibrary.all.count)
    }

    @Test(arguments: TemplateCategory.allCases)
    func everyCategoryHasEnough(category: TemplateCategory) {
        #expect(TemplateLibrary.templates(in: category).count >= 5)
    }

    @Test func everyTemplateIsComplete() {
        for t in TemplateLibrary.all {
            #expect(DraftCleaner.clean(t.draft) != nil, "\(t.id)")
            #expect(Experiment.durations.contains(t.days), "\(t.id)")
            #expect(!t.tip.isEmpty && !t.pitfall.isEmpty && !t.reason.isEmpty, "\(t.id)")
            #expect(!t.keywords.isEmpty, "\(t.id)")
            #expect(t.draft.templateID == t.id)
        }
    }

    @Test func noMedicalOrDietTemplates() {
        for t in TemplateLibrary.all {
            let text = [t.title, t.action, t.question, t.reason, t.tip, t.pitfall].joined(separator: " ").lowercased()
            for word in DraftCleaner.blockedWords {
                #expect(!text.contains(word.lowercased()), "\(t.id): \(word)")
            }
        }
    }

    @Test func blockedWordsAreRejected() {
        for word in ["断食", "ダイエット", "処方", "サプリ"] {
            #expect(DraftCleaner.clean(draft("\(word)をためす")) == nil, "\(word)")
        }
    }
}

// MARK: - 案を考える役（偽物）

struct FakeDesigner: ExperimentDesigner {
    var status: DesignerStatus = .available
    var drafts: [ExperimentDraft]

    func design(worry: String) async throws -> [ExperimentDraft] {
        guard !worry.isEmpty else { throw DesignError.emptyInput }
        return DraftCleaner.cleanAll(drafts)
    }
}

struct DesignerTests {
    @Test func fakeDesignerFiltersUnsafeDrafts() async throws {
        let designer = FakeDesigner(drafts: [draft("歩く"), ExperimentDraft(title: "断食", action: "食べない", question: "体調は？", lowLabel: "", highLabel: "", reason: "", source: .model)])
        let result = try await designer.design(worry: "だるい")
        #expect(result.map(\.title) == ["歩く"])
    }

    @Test func unavailableDesignerExplains() async {
        let designer = UnavailableDesigner(reason: "使えません")
        #expect(designer.status == .unavailable("使えません"))
        await #expect(throws: DesignError.self) { try await designer.design(worry: "x") }
    }
}

// MARK: - 保存

@MainActor
struct StoreTests {
    @Test func seedsSamplesOnce() {
        let store = makeStore(seedSamples: true)
        #expect(store.experiments.count == 4)
        #expect(store.finished(now: day(4)).count == 3)
        #expect(store.active(now: day(4)).count == 1)
        let finished = store.finished(now: day(4)).first { !$0.endedEarly }
        #expect(finished.map { Analyzer.result(for: $0).verdict } == .better)
        #expect(store.finished(now: day(4)).contains { $0.endedEarly })
        #expect(store.provenHabits(now: day(4)).count == 1)
        // 進行中の見本：4 日目。今日のくじはまだ、2 日目の記録が抜けている
        let active = store.active(now: day(4))[0]
        #expect(active.today(on: day(4), calendar: tokyo) == 3)
        #expect(!active.isRevealed(day: 3))
        #expect(active.pendingDays(on: day(4), calendar: tokyo) == [3, 1])
        #expect(active.templateID == "focus-lunch-walk")
        #expect(store.streak(now: day(4)) == 1)
        #expect(store.recordedDayCount == 30)
    }

    @Test func restartCopiesTheExperiment() throws {
        let store = makeStore()
        var original = draft()
        original.templateID = "focus-lunch-walk"
        let id = try #require(store.start(original, duration: 8, now: day(1), seed: 3))
        store.endEarly(id: id)
        let again = try #require(store.restart(id: id, now: day(4), seed: 4))
        let copy = try #require(store.experiment(id: again))
        #expect(copy.title == original.title)
        #expect(copy.templateID == "focus-lunch-walk")
        #expect(copy.duration == 8)
        #expect(copy.checkIns.isEmpty)
        #expect(store.active(now: day(4)).map(\.id) == [again])
    }

    @Test func startRecordAndReveal() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(), duration: 8, now: day(4), seed: 5))
        #expect(store.active(now: day(4)).map(\.id) == [id])
        store.reveal(id: id, day: 0)
        #expect(store.experiment(id: id)?.isRevealed(day: 0) == true)
        #expect(store.record(id: id, day: 0, rating: 4, followed: true, now: day(4)))
        #expect(store.streak(now: day(4)) == 1)
        // 上書き
        #expect(store.record(id: id, day: 0, rating: 2, followed: false, now: day(4)))
        #expect(store.experiment(id: id)?.checkIns.count == 1)
        #expect(store.experiment(id: id)?.checkIn(day: 0)?.rating == 2)
    }

    @Test func rejectsFutureDaysAndBadRatings() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(), now: day(4), seed: 5))
        #expect(!store.record(id: id, day: 1, rating: 3, followed: true, now: day(4)))
        #expect(!store.record(id: id, day: 0, rating: 6, followed: true, now: day(4)))
        #expect(!store.record(id: id, day: 0, rating: 0, followed: true, now: day(4)))
    }

    @Test func nextMorningCannotRecordTodayYet() throws {
        let store = makeStore()
        var morning = draft()
        morning.nextMorning = true
        let id = try #require(store.start(morning, duration: 8, now: day(4), seed: 5))
        #expect(!store.record(id: id, day: 0, rating: 3, followed: true, now: day(4, hour: 22)))
        #expect(store.record(id: id, day: 0, rating: 3, followed: true, now: day(5, hour: 7)))
        #expect(store.streak(now: day(5)) == 1)
    }

    @Test func unknownDurationFallsBackToDefault() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(), duration: 3, now: day(4), seed: 5))
        #expect(store.experiment(id: id)?.duration == Experiment.defaultDuration)
    }

    @Test func endEarlyMovesToFinished() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(), now: day(4), seed: 5))
        store.endEarly(id: id)
        #expect(store.finished(now: day(4)).map(\.id) == [id])
        #expect(!store.record(id: id, day: 0, rating: 3, followed: true, now: day(4)))
    }

    @Test func persistsAcrossInstances() throws {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let first = ExperimentStore(defaults: defaults, key: "e", seedSamples: false, now: day(4), calendar: tokyo)
        let id = try #require(first.start(draft(), now: day(4), seed: 9))
        first.record(id: id, day: 0, rating: 5, followed: true, now: day(4))
        let second = ExperimentStore(defaults: defaults, key: "e", seedSamples: true, now: day(4), calendar: tokyo)
        #expect(second.experiments.count == 1)
        #expect(second.experiment(id: id)?.checkIn(day: 0)?.rating == 5)
        second.delete(id: id)
        let third = ExperimentStore(defaults: defaults, key: "e", seedSamples: true, now: day(4), calendar: tokyo)
        #expect(third.experiments.isEmpty)
        defaults.removePersistentDomain(forName: name)
    }
}
