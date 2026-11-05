import SwiftUI

/// はじめの 3 ページ：くじ（動く見本）→ 方眼の記録 → ハンコとプライバシー
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            Palette.desk.ignoresSafeArea()
            VStack(spacing: Space.l) {
                TabView(selection: $page) {
                    pageView(
                        title: "思い込みを、実験に。",
                        text: "「スマホを置くと朝がすっきりする気がする」。その「気がする」を確かめます。毎朝おみくじの筒を振って、今日が「やる日」か「やすむ日」かを決めます。",
                        art: AnyView(OmikujiDemo().frame(height: 250))
                    )
                    .tag(0)
                    pageView(
                        title: "方眼のノートに、1 日 1 つの点数。",
                        text: "夜（または翌朝）に、決めた質問へ 1〜5 で答えるだけ。やる日は朱、やすむ日は藍のマスが埋まっていきます。",
                        art: AnyView(sampleTable)
                    )
                    .tag(1)
                    pageView(
                        title: "8〜14 日後、ハンコが押されます。",
                        text: "やる日とやすむ日をくらべて、「効果あり」「差は小さい」を、偶然の確率と一緒に言葉で出します。記録は iPhone の中だけ。外には送りません。",
                        art: AnyView(Hanko(verdict: .better, size: 170).popIn().frame(height: 250))
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: Space.s) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Palette.shu.deep : Palette.line)
                            .frame(width: index == page ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
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
                .buttonStyle(StampButtonStyle())
                .padding(.horizontal, Space.xl)
                .haptic(.selection, trigger: page)

                Button("とばす", action: onFinish)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(minHeight: 44)
            }
            .padding(.vertical, Space.xl)
            .frame(maxWidth: 560)
        }
    }

    private var sampleTable: some View {
        let sample = Samples.experiments(now: .now, calendar: .current).first { !$0.endedEarly && $0.checkIns.count > 10 }
        return Group {
            if let sample {
                RecordTable(experiment: sample, today: nil)
                    .frame(maxWidth: 260)
                    .padding(Space.l)
                    .background(Palette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.page, style: .continuous))
                    .paperShadow()
                    .rotationEffect(.degrees(-2))
            }
        }
        .frame(height: 250)
    }

    private func pageView(title: String, text: String, art: AnyView) -> some View {
        VStack(spacing: Space.xl) {
            Spacer(minLength: 0)
            art
            NotebookPage(showsClip: false) {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text(title)
                        .font(Typo.title(.title2))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Space.xl)
            Spacer(minLength: 0)
        }
    }
}
