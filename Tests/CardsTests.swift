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

private func draft(_ title: String = "昼食のあと歩く", nextMorning: Bool = false, templateID: String? = nil) -> ExperimentDraft {
    var d = ExperimentDraft(title: title, action: "10 分歩く", question: "午後の集中は？", lowLabel: "", highLabel: "", reason: "", source: .manual)
    d.nextMorning = nextMorning
    d.templateID = templateID
    return d
}

@MainActor
private func makeStore(seedSamples: Bool = false, now: Date = day(4)) -> ExperimentStore {
    let name = "cards-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return ExperimentStore(defaults: defaults, key: "experiments", seedSamples: seedSamples, now: now, calendar: tokyo)
}

/// くじのとおりに、やる日とやすむ日の点数を入れた実験
private func experiment(doRating: (Int) -> Int, restRating: (Int) -> Int, duration: Int = 14, seed: UInt64 = 11, prediction: Prediction? = nil, templateID: String? = nil) -> Experiment {
    var e = Experiment(title: "t", action: "a", question: "q", lowLabel: "l", highLabel: "h", reason: "", startDate: day(1), duration: duration, seed: seed)
    e.prediction = prediction
    e.templateID = templateID
    for (d, arm) in e.schedule.enumerated() {
        let rating = arm == .doIt ? doRating(d) : restRating(d)
        e.checkIns.append(CheckIn(day: d, rating: rating, followed: true, note: "", recordedAt: day(1)))
    }
    return e
}

// MARK: - カードの決まり

struct CardRulesTests {
    @Test func starsFollowTheEvidence() {
        #expect(CardRules.stars(verdict: .better, pValue: 0.005, comparedDays: 14) == 3)
        #expect(CardRules.stars(verdict: .better, pValue: 0.03, comparedDays: 14) == 2)
        #expect(CardRules.stars(verdict: .worse, pValue: 0.09, comparedDays: 14) == 1)
        #expect(CardRules.stars(verdict: .noClearDifference, pValue: 0.6, comparedDays: 14) == 2)
        #expect(CardRules.stars(verdict: .noClearDifference, pValue: 0.6, comparedDays: 8) == 1)
        #expect(CardRules.stars(verdict: .notEnough, pValue: 1, comparedDays: 2) == 0)
    }

    @Test func predictionOutcome() {
        #expect(PredictionOutcome.of(prediction: .works, kind: .proven) == .matched)
        #expect(PredictionOutcome.of(prediction: .works, kind: .myth) == .overturned)
        #expect(PredictionOutcome.of(prediction: .doesNotWork, kind: .proven) == .overturned)
        #expect(PredictionOutcome.of(prediction: .doesNotWork, kind: .backfire) == .matched)
        #expect(PredictionOutcome.of(prediction: .unsure, kind: .proven) == .none)
        #expect(PredictionOutcome.of(prediction: nil, kind: .myth) == .none)
    }

    @Test func clearEffectBecomesAProvenCard() throws {
        let e = experiment(doRating: { _ in 5 }, restRating: { _ in 2 }, prediction: .doesNotWork)
        let card = try #require(CardRules.card(for: e))
        #expect(card.kind == .proven)
        #expect(card.stars == 3)
        #expect(card.outcome == .overturned)
        #expect(card.comparedDays == 14)
        #expect(card.difference == 3)
    }

    @Test func noDifferenceBecomesAMythCard() throws {
        let e = experiment(doRating: { _ in 3 }, restRating: { _ in 3 }, prediction: .works)
        let card = try #require(CardRules.card(for: e))
        #expect(card.kind == .myth)
        #expect(card.outcome == .overturned)
    }

    @Test func tooFewDaysGiveNoCard() {
        var e = Experiment(title: "t", action: "a", question: "q", lowLabel: "l", highLabel: "h", reason: "", startDate: day(1), duration: 14, seed: 3)
        e.checkIns = [CheckIn(day: 0, rating: 4, followed: true, note: "", recordedAt: day(1))]
        #expect(CardRules.card(for: e) == nil)
    }

    @Test func bestCardPrefersStarsThenKindThenNewest() {
        let strongMyth = experiment(doRating: { _ in 3 }, restRating: { _ in 3 })
        let strongProven = experiment(doRating: { _ in 5 }, restRating: { _ in 1 })
        let cards = [strongMyth, strongProven].compactMap(CardRules.card(for:))
        #expect(CardBook.best(cards)?.kind == .proven)
        var a = CardRules.card(for: strongProven)!
        var b = a
        a.experimentID = UUID()
        b.experimentID = UUID()
        #expect(CardBook.best([a, b])?.experimentID == a.experimentID)
    }
}

// MARK: - 図鑑

@MainActor
struct CardBookTests {
    @Test func samplesFillTwoSlotsAtLeast() {
        let store = makeStore(seedSamples: true)
        let cards = CardBook.cards(experiments: store.experiments, now: day(4), calendar: tokyo)
        let slots = CardBook.slots(cards)
        #expect(slots["sleep-phone-away"]?.kind == .proven)
        #expect(slots["sleep-phone-away"]?.outcome == .matched)
        #expect(slots["morning-water"]?.kind == .myth)
        #expect(slots["morning-water"]?.outcome == .overturned)
        #expect(CardBook.discovered(cards) >= 2)
        #expect(CardBook.overturned(cards) >= 1)
        #expect(CardBook.custom(cards).isEmpty)
    }

    @Test func customExperimentsAreTheirOwnSlot() {
        let e = experiment(doRating: { _ in 5 }, restRating: { _ in 2 })
        let cards = [e].compactMap(CardRules.card(for:))
        #expect(CardBook.custom(cards).count == 1)
        #expect(CardBook.discovered(cards) == 1)
    }

    @Test func replicatedGroupsByTemplate() {
        let first = experiment(doRating: { _ in 5 }, restRating: { _ in 2 }, templateID: "focus-top3")
        let second = experiment(doRating: { _ in 4 }, restRating: { _ in 3 }, seed: 12, templateID: "focus-top3")
        let cards = [first, second].compactMap(CardRules.card(for:))
        #expect(CardBook.replicated(cards)["focus-top3"]?.count == 2)
        #expect(CardBook.slots(cards).count == 1)
    }
}

// MARK: - けさの開封

@MainActor
struct MorningDeckTests {
    @Test func sampleDeckIsRecapEvidenceLot() throws {
        let store = makeStore(seedSamples: true)
        let active = try #require(store.active(now: day(4)).first)
        let deck = MorningDeck.cards(experiments: store.experiments, now: day(4), calendar: tokyo)
        #expect(deck == [.recap(experimentID: active.id, day: 2), .evidence(experimentID: active.id), .lot(experimentID: active.id, day: 3)])
        store.reveal(id: active.id, day: 3)
        #expect(MorningDeck.cards(experiments: store.experiments, now: day(4), calendar: tokyo).isEmpty)
    }

    @Test func missingRecordComesFirst() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(), duration: 8, now: day(1), seed: 5))
        let deck = MorningDeck.cards(experiments: store.experiments, now: day(2), calendar: tokyo)
        #expect(deck == [.missing(experimentID: id, day: 0), .evidence(experimentID: id), .lot(experimentID: id, day: 1)])
        #expect(store.record(id: id, day: 0, rating: 4, followed: true, now: day(2)))
        #expect(MorningDeck.cards(experiments: store.experiments, now: day(2), calendar: tokyo).first == .recap(experimentID: id, day: 0))
    }

    @Test func firstDayHasNoRecap() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(nextMorning: true), duration: 8, now: day(1), seed: 5))
        #expect(MorningDeck.cards(experiments: store.experiments, now: day(1), calendar: tokyo) == [.evidence(experimentID: id), .lot(experimentID: id, day: 0)])
        // 翌朝に記録する実験は、きのうの分をけさ記録できる
        #expect(MorningDeck.cards(experiments: store.experiments, now: day(2, hour: 7), calendar: tokyo).first == .missing(experimentID: id, day: 0))
    }

    @Test func finishedExperimentGetsAVerdictUntilAnnounced() throws {
        let store = makeStore()
        let id = try #require(store.start(draft(), duration: 8, prediction: .works, now: day(1), seed: 5))
        for d in 0..<8 {
            let arm = store.experiment(id: id)!.arm(day: d)!
            #expect(store.record(id: id, day: d, rating: arm == .doIt ? 5 : 2, followed: true, now: day(9)))
        }
        let deck = MorningDeck.cards(experiments: store.experiments, now: day(9), calendar: tokyo)
        #expect(deck == [.verdict(experimentID: id)])
        store.announce(id: id)
        #expect(MorningDeck.cards(experiments: store.experiments, now: day(9), calendar: tokyo).isEmpty)
        #expect(store.experiment(id: id)?.prediction == .works)
    }

    @Test func daysUntilVerdict() {
        var e = Experiment(title: "t", action: "a", question: "q", lowLabel: "l", highLabel: "h", reason: "", startDate: day(1), duration: 14, seed: 1)
        #expect(MorningDeck.daysUntilVerdict(e, today: 3) == 10)
        #expect(MorningDeck.daysUntilVerdict(e, today: 13) == 0)
        e.nextMorning = true
        #expect(MorningDeck.daysUntilVerdict(e, today: 13) == 1)
    }

    @Test func oldSavesWithoutNewFieldsStillLoad() throws {
        let json = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"t","action":"a","question":"q","lowLabel":"l","highLabel":"h","reason":"",
          "startDate":0,"duration":8,"seed":1,"checkIns":[],"revealedDays":[],"endedEarly":false,"isSample":false,"nextMorning":false}]
        """
        let decoded = try JSONDecoder().decode([Experiment].self, from: Data(json.utf8))
        #expect(decoded.first?.prediction == nil)
        #expect(decoded.first?.announced == nil)
    }
}

// MARK: - Pro

struct ProTests {
    @Test func activeLimits() {
        #expect(ProGate.canStartAnother(activeCount: 0, isPro: false))
        #expect(!ProGate.canStartAnother(activeCount: 1, isPro: false))
        #expect(ProGate.canStartAnother(activeCount: 2, isPro: true))
        #expect(!ProGate.canStartAnother(activeCount: 3, isPro: true))
    }

    @Test func proTemplatesHaveOneTrial() throws {
        let pro = try #require(TemplateLibrary.all.first { $0.isPro })
        let other = try #require(TemplateLibrary.all.last { $0.isPro })
        let free = try #require(TemplateLibrary.all.first { !$0.isPro })
        #expect(ProGate.canUse(free, isPro: false, trialTemplateID: "x"))
        #expect(ProGate.canUse(pro, isPro: false, trialTemplateID: nil))
        #expect(ProGate.canUse(pro, isPro: false, trialTemplateID: pro.id))
        #expect(!ProGate.canUse(other, isPro: false, trialTemplateID: pro.id))
        #expect(ProGate.canUse(other, isPro: true, trialTemplateID: pro.id))
    }

    @Test func proFeaturesAreConcrete() {
        #expect(ProFeature.allCases.count >= 3)
        for feature in ProFeature.allCases {
            #expect(!feature.title.isEmpty && !feature.detail.isEmpty)
        }
    }

    @Test func replicationFindsAConsistentEffect() throws {
        let runs = [
            Replication.Run(doRatings: [5, 4, 5, 4, 5, 4, 5], restRatings: [2, 3, 2, 3, 2, 3, 2]),
            Replication.Run(doRatings: [4, 5, 4, 4], restRatings: [3, 2, 3, 2]),
        ]
        let combined = try #require(Replication.combined(runs, samples: 4_000))
        #expect(combined.runs == 2)
        #expect(combined.meanDifference > 1.5)
        #expect(combined.pValue < 0.01)
        // 同じ入力なら同じ答え
        #expect(Replication.combined(runs, samples: 4_000) == combined)
    }

    @Test func replicationWithoutDifferenceIsNotSignificant() throws {
        let runs = [
            Replication.Run(doRatings: [3, 3, 3], restRatings: [3, 3, 3]),
            Replication.Run(doRatings: [4, 4], restRatings: [4, 4]),
        ]
        let combined = try #require(Replication.combined(runs, samples: 500))
        #expect(combined.pValue == 1)
        #expect(Replication.combined([runs[0]]) == nil)
    }

    @Test func csvEscapesAndListsEveryRecord() {
        var e = experiment(doRating: { _ in 4 }, restRating: { _ in 2 }, duration: 8)
        e.title = "歩く, 10 分"
        e.checkIns[0].note = "\"よかった\""
        let csv = CSVExport.text([e], calendar: tokyo)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 9)
        #expect(lines[0] == "実験,日,日付,くじ,点数,くじのとおり,メモ")
        #expect(lines[1].hasPrefix("\"歩く, 10 分\",1,2026-11-01,"))
        #expect(lines[1].hasSuffix("\"\"\"よかった\"\"\""))
    }
}
