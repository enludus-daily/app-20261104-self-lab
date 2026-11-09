import SwiftUI

/// はじめの 3 ページ：伏せたカードをめくる（動く見本）→ 毎朝の開封 → 結果がカードになる
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    private let samples = Samples.experiments(now: .now, calendar: .current)

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()
            VStack(spacing: Space.l) {
                TabView(selection: $page) {
                    pageView(
                        title: "思い込みを、カードにする。",
                        text: "「スマホを置くと朝がすっきりする気がする」。その「気がする」を確かめます。毎朝カードをめくると、きょうが「やる日」か「やすむ日」かが出ます。",
                        art: AnyView(FlipDemo(experiment: samples.first { !$0.isFinished(on: .now, calendar: .current) }))
                    )
                    .tag(0)
                    pageView(
                        title: "記録すると、あすのカードが増える。",
                        text: "夜（または翌朝）に、決めた質問へ 1〜5 で答えるだけ。けさの開封で、きのうの記録・集まった証拠・きょうのくじを 1 枚ずつめくります。",
                        art: AnyView(DeckStack(count: 3, width: 140, caption: "3 枚").frame(height: 230))
                    )
                    .tag(1)
                    pageView(
                        title: "最後の日、結果発表。",
                        text: "くじを全部の組み合わせで入れ替えてくらべ、「効いた」「思い込みだった」「逆効果」のカードにします。★は証拠の強さ。記録は iPhone の中だけです。",
                        art: AnyView(resultCards)
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: Space.s) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Palette.sky.deep : Palette.line)
                            .frame(width: index == page ? 22 : 8, height: 8)
                            .animation(.easeOut(duration: 0.25), value: page)
                    }
                }
                .accessibilityHidden(true)

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < 2 ? "次へ" : "はじめる")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Space.xl)
                .haptic(.selection, trigger: page)

                Button("とばす", action: onFinish)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(minHeight: 44)
            }
            .padding(.vertical, Space.l)
            .frame(maxWidth: 560)
        }
    }

    private var resultCards: some View {
        let cards = samples.filter { $0.isFinished(on: .now, calendar: .current) }.compactMap(CardRules.card(for:))
        return ZStack {
            ForEach(Array(cards.prefix(2).enumerated()), id: \.element.id) { offset, card in
                CardFace(card: card, width: 128)
                    .rotationEffect(.degrees(offset == 0 ? 6 : -6))
                    .offset(x: offset == 0 ? 52 : -52)
                    .liftedShadow()
            }
        }
        .frame(height: 230)
    }

    private func pageView(title: String, text: String, art: AnyView) -> some View {
        VStack(spacing: Space.l) {
            Spacer(minLength: 0)
            art
            VStack(alignment: .leading, spacing: Space.s) {
                Text(title)
                    .font(Typo.title(.title2))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
            Spacer(minLength: 0)
        }
    }
}

/// オンボーディングの動く見本：伏せたカードが、くり返しめくれる
struct FlipDemo: View {
    let experiment: Experiment?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipped = false

    var body: some View {
        Group {
            if let experiment {
                FlipCard(flipped: flipped) {
                    LotFace(experiment: experiment, day: 3, width: 150)
                } back: {
                    CardBack(width: 150, label: "きょうのくじ")
                }
                .liftedShadow()
            }
        }
        .frame(height: 230)
        .task {
            guard !reduceMotion else {
                flipped = true
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { flipped.toggle() }
            }
        }
    }
}
