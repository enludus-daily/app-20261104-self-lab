import SwiftUI

// 世界観の主役：習慣のカード（5:7）。表＝結果、裏＝くじ・結果発表の前。
// 自作の部品：CardFrame（二重の細い枠）、CardBack（点の模様と紋章）、FoilSheen（★2 以上の箔のきらめき）、FlipCard（めくる）。

enum CardMetrics {
    static let aspect: CGFloat = 7.0 / 5.0
    static let baseWidth: CGFloat = 280

    static func height(for width: CGFloat) -> CGFloat { width * aspect }
}

/// カードの縁：外の角丸と、内側の細い枠
struct CardFrame: View {
    let swatch: Swatch
    let scale: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous)
                .fill(swatch.paper)
            RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.6)
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .strokeBorder(swatch.accent.opacity(0.7), lineWidth: 0.8)
                .padding(8 * scale)
        }
    }
}

/// 箔のきらめき（★2 以上）。斜めの淡い光の帯が、ゆっくり横切る。動きを減らす設定では止まる
struct FoilSheen: View {
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(colorScheme == .dark ? 0.12 : 0.45), .white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.5)
            .rotationEffect(.degrees(20))
            .offset(x: phase * width)
            .blendMode(.plusLighter)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous))
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else {
                phase = 0.2
                return
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: false).delay(0.6)) {
                phase = 1.4
            }
        }
        .accessibilityHidden(true)
    }
}

/// カードの表（結果）
struct CardFace: View {
    let card: HabitCard
    var width: CGFloat = CardMetrics.baseWidth

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        let swatch = Palette.swatch(for: card.kind)
        let compact = width < 170
        ZStack {
            CardFrame(swatch: swatch, scale: scale)
            if compact {
                compactBody(swatch: swatch, scale: scale)
            } else {
                VStack(spacing: 10 * scale) {
                    HStack(alignment: .center) {
                        Text(card.category?.title ?? "じぶんの型")
                            .font(.system(size: 11 * scale, weight: .medium))
                            .kerning(0.6)
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        StarRow(stars: card.stars, color: swatch.deep, size: 11 * scale)
                    }
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().fill(swatch.soft)
                        Circle().strokeBorder(swatch.accent, lineWidth: 0.8)
                        Image(systemName: card.symbol)
                            .font(.system(size: 42 * scale, weight: .light))
                            .foregroundStyle(swatch.deep)
                    }
                    .frame(width: 112 * scale, height: 112 * scale)
                    Text(card.title)
                        .font(.system(size: 19 * scale, weight: .medium, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Label(card.kind.title, systemImage: card.kind.symbol)
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundStyle(swatch.deep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10 * scale)
                        .padding(.vertical, 4 * scale)
                        .background(Capsule().fill(swatch.soft))
                    HStack(spacing: 14 * scale) {
                        figure("差", ResultText.signed(card.difference), scale: scale)
                        figure("偶然", ResultText.percent(card.pValue), scale: scale)
                        figure("日数", "\(card.comparedDays)", scale: scale)
                    }
                    if let outcome = card.outcome.title {
                        Text(outcome)
                            .font(.system(size: 11 * scale, weight: .medium))
                            .kerning(0.6)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.horizontal, 20 * scale)
                .padding(.vertical, 22 * scale)
            }
            if card.stars >= 2 {
                FoilSheen(scale: scale)
            }
        }
        .frame(width: width, height: CardMetrics.height(for: width))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.title)。\(card.kind.title)。★\(card.stars)")
    }

    /// 小さなカード（図鑑の一覧・ホームの新着）：印・題・★・種類の印だけを、読める大きさで
    private func compactBody(swatch: Swatch, scale: CGFloat) -> some View {
        VStack(spacing: 6) {
            HStack {
                StarRow(stars: card.stars, color: swatch.deep, size: 8)
                Spacer(minLength: 0)
                Image(systemName: card.kind.symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(swatch.deep)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(swatch.soft)
                Circle().strokeBorder(swatch.accent, lineWidth: 0.6)
                Image(systemName: card.symbol)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(swatch.deep)
            }
            .frame(width: 44, height: 44)
            Text(card.title)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            Text(card.kind.title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(swatch.deep)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private func figure(_ label: String, _ value: String, scale: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14 * scale, weight: .regular, design: .serif).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9 * scale, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

/// カードの裏：淡い sky の地に点の模様と、真ん中の紋章（試験管）
struct CardBack: View {
    var width: CGFloat = CardMetrics.baseWidth
    var label: String?
    var caption: String?

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        let swatch = Palette.sky
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous)
                .fill(swatch.soft)
            Canvas { context, size in
                let step = 14 * scale
                var y = step / 2
                var row = 0
                while y < size.height {
                    var x = (row.isMultiple(of: 2) ? step / 2 : step)
                    while x < size.width {
                        let r = 1.1 * scale
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(swatch.decor))
                        x += step
                    }
                    y += step * 0.866
                    row += 1
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous))
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .strokeBorder(swatch.accent.opacity(0.8), lineWidth: 0.8)
                .padding(8 * scale)
            VStack(spacing: 10 * scale) {
                ZStack {
                    Circle().fill(Palette.card)
                    Circle().strokeBorder(swatch.accent, lineWidth: 0.8)
                    Image(systemName: "testtube.2")
                        .font(.system(size: 34 * scale, weight: .light))
                        .foregroundStyle(swatch.deep)
                }
                .frame(width: 84 * scale, height: 84 * scale)
                if let label {
                    Text(label)
                        .font(.system(size: 18 * scale, weight: .medium, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                if let caption {
                    Text(caption)
                        .font(.system(size: 11 * scale, weight: .medium))
                        .kerning(0.6)
                        .foregroundStyle(swatch.deep)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(24 * scale)
        }
        .frame(width: width, height: CardMetrics.height(for: width))
    }
}

/// まだ手に入れていない枠（図鑑）。点線の枠と、うすい印
struct EmptySlot: View {
    let template: ExperimentTemplate
    var width: CGFloat = 110
    var locked = false

    var body: some View {
        let scale = width / CardMetrics.baseWidth
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous)
                .fill(Palette.card.opacity(0.6))
            RoundedRectangle(cornerRadius: Radius.card * scale, style: .continuous)
                .strokeBorder(Palette.inkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
            VStack(spacing: 6) {
                Image(systemName: template.symbol)
                    .font(.system(size: max(16, 52 * scale), weight: .light))
                    .foregroundStyle(Palette.inkSoft.opacity(0.5))
                Text(template.title)
                    .font(.system(size: max(10, 22 * scale), weight: .regular, design: .serif))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            if locked {
                VStack {
                    HStack {
                        Spacer()
                        Text("Pro")
                            .font(.system(size: max(9, 22 * scale), weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(Palette.sky.deep)
                            .padding(.horizontal, 10 * scale)
                            .padding(.vertical, 4 * scale)
                            .background(Capsule().fill(Palette.sky.soft))
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(width: width, height: CardMetrics.height(for: width))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.title)。まだ")
    }
}

/// めくるカード。裏から表へ、縦の軸で回る。動きを減らす設定ではフェードで入れ替える
struct FlipCard<Front: View, Back: View>: View {
    let flipped: Bool
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            back
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (flipped ? 180 : 0)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            front
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (flipped ? 0 : -180)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        }
    }
}

/// 重ねた伏せカード（ホームの「けさの開封」）
struct DeckStack: View {
    let count: Int
    var width: CGFloat = 170
    var caption: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        let layers = min(max(count, 1), 3)
        ZStack {
            ForEach(0..<layers, id: \.self) { index in
                let depth = layers - 1 - index
                CardBack(width: width, label: index == layers - 1 ? "けさの開封" : nil, caption: index == layers - 1 ? caption : nil)
                    .rotationEffect(.degrees(Double(depth) * (depth.isMultiple(of: 2) ? 4 : -4)))
                    .offset(x: CGFloat(depth) * 10, y: CGFloat(depth) * -4)
                    .modifier(TopShadow(isTop: index == layers - 1))
            }
        }
        .scaleEffect(breathe ? 1.02 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("けさの開封。\(count) 枚")
    }
}

private struct TopShadow: ViewModifier {
    let isTop: Bool

    func body(content: Content) -> some View {
        if isTop {
            content.liftedShadow()
        } else {
            content.softShadow()
        }
    }
}

/// やる日・やすむ日の札
struct ArmPill: View {
    let arm: Arm

    var body: some View {
        let swatch = Palette.swatch(for: arm)
        Label(arm.title, systemImage: arm == .doIt ? "sun.max" : "moon")
            .font(.caption.weight(.semibold))
            .foregroundStyle(swatch.deep)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(Capsule().fill(swatch.soft))
            .fixedSize()
    }
}

/// 実験の日の並び（点）。記録した日は点数の濃さ、くじのとおりでない日は輪だけ、今日は細い輪
struct DayDots: View {
    let experiment: Experiment
    let today: Int?
    var size: CGFloat = 14

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: size + 4, maximum: size + 8), spacing: 4)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(0..<experiment.duration, id: \.self) { day in
                dot(day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(experiment.duration) 日のうち \(experiment.checkIns.count) 日記録")
    }

    @ViewBuilder
    private func dot(_ day: Int) -> some View {
        let arm = experiment.isRevealed(day: day) ? experiment.arm(day: day) : nil
        let swatch = arm.map { Palette.swatch(for: $0) } ?? Palette.mist
        let checkIn = experiment.checkIn(day: day)
        ZStack {
            if let checkIn, checkIn.followed {
                Circle().fill(swatch.accent.opacity(Palette.ratingOpacity(checkIn.rating)))
            } else if checkIn != nil {
                Circle().strokeBorder(swatch.accent, lineWidth: 1)
            } else {
                Circle().fill(arm == nil ? Palette.mist.soft : swatch.soft)
            }
            if day == today {
                Circle().strokeBorder(Palette.sky.deep, lineWidth: 1).padding(-3)
            }
        }
        .frame(width: size, height: size)
    }
}
