import SwiftUI

// 世界観の部品（自作の Shape / Canvas）。理科の実験ノート・クリップ・ラベルシール・ハンコ。

/// 方眼の記録用紙：方眼 16pt・線 0.5、左に余白の赤線
struct GridPaper: View {
    var spacing: CGFloat = 16
    var marginX: CGFloat? = 28

    var body: some View {
        Canvas { context, size in
            var grid = Path()
            var x: CGFloat = 0
            while x <= size.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(grid, with: .color(Palette.grid), lineWidth: 0.5)
            if let marginX {
                var margin = Path()
                margin.move(to: CGPoint(x: marginX, y: 0))
                margin.addLine(to: CGPoint(x: marginX, y: size.height))
                context.stroke(margin, with: .color(Palette.margin), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// クリップ（紙をとめる針金）
struct PaperClip: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.34))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.80))
        p.addCurve(
            to: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.80),
            control1: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 1.02),
            control2: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 1.02)
        )
        p.addLine(to: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.14))
        p.addCurve(
            to: CGPoint(x: rect.minX + w * 0.88, y: rect.minY + h * 0.14),
            control1: CGPoint(x: rect.minX + w * 0.18, y: rect.minY - h * 0.06),
            control2: CGPoint(x: rect.minX + w * 0.88, y: rect.minY - h * 0.06)
        )
        p.addLine(to: CGPoint(x: rect.minX + w * 0.88, y: rect.minY + h * 0.70))
        return p
    }
}

/// 実験ノートの 1 ページ：方眼の紙・余白の赤線・右上のクリップ
struct NotebookPage<Content: View>: View {
    var tilt: Double = 0
    var showsClip = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.leading, 40)
            .padding(.trailing, Space.l)
            .padding(.vertical, Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.page, style: .continuous)
                        .fill(Palette.paper)
                    GridPaper()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.page, style: .continuous))
                }
                .paperShadow()
            }
            .overlay(alignment: .topTrailing) {
                if showsClip {
                    PaperClip()
                        .stroke(Palette.clip, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 20, height: 52)
                        .rotationEffect(.degrees(6))
                        .offset(x: -28, y: -18)
                        .accessibilityHidden(true)
                }
            }
            .rotationEffect(.degrees(tilt))
    }
}

/// ラベルシール：左に色の帯、少し傾けて貼る
struct LabelSticker: View {
    let text: String
    var color: Color = Palette.shu.accent
    var tilt: Double = -2
    var font: Font = Typo.title(.title3)

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 6)
            Text(text)
                .font(font)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.label)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.8)
        )
        .edgeShadow()
        .rotationEffect(.degrees(tilt))
    }
}

/// 斜線（くじのとおりにできなかった日）
struct Hatch: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            var p = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 5
            }
            context.stroke(p, with: .color(color), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// 朱肉のかすれ（固定の乱数で毎回同じ）
struct InkGrain: View {
    var seed: UInt64 = 7
    var count = 140

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.blendMode = .clear
            var rng = SplitMix64(state: seed)
            for _ in 0..<count {
                let x = CGFloat(rng.next() % 1000) / 1000 * size.width
                let y = CGFloat(rng.next() % 1000) / 1000 * size.height
                let r = CGFloat(rng.next() % 100) / 100 * 2.2 + 0.4
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.black))
            }
        }
    }
}

/// 結果のハンコ。効果あり＝朱の二重丸、途中＝鉛筆の点線
struct Hanko: View {
    let verdict: ExperimentResult.Verdict
    var size: CGFloat = 120
    var inProgress = false

    var body: some View {
        let color = inProgress ? Palette.inkSoft : Palette.verdict(verdict)
        let lines = Self.lines(verdict, inProgress: inProgress)
        ZStack {
            if inProgress || verdict == .notEnough {
                Circle()
                    .stroke(color, style: StrokeStyle(lineWidth: size * 0.03, dash: [size * 0.06, size * 0.045]))
                    .padding(size * 0.02)
            } else {
                Circle().strokeBorder(color, lineWidth: size * 0.05)
                Circle().inset(by: size * 0.1).strokeBorder(color, lineWidth: size * 0.016)
            }
            VStack(spacing: -size * 0.02) {
                Text(lines.0)
                Text(lines.1)
            }
            .font(.system(size: size * 0.2, weight: .heavy, design: .serif))
            .foregroundStyle(color)
            .minimumScaleFactor(0.6)
            .padding(size * 0.14)
        }
        .frame(width: size, height: size)
        .mask(InkGrain(seed: 11, count: Int(size * 1.4)))
        .rotationEffect(.degrees(-12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ハンコ：\(lines.0)\(lines.1)")
    }

    static func lines(_ verdict: ExperimentResult.Verdict, inProgress: Bool) -> (String, String) {
        if inProgress { return ("記録", "途中") }
        switch verdict {
        case .better: return ("効果", "あり")
        case .worse: return ("逆効果", "かも")
        case .noClearDifference: return ("差は", "小さい")
        case .notEnough: return ("まだ", "不明")
        }
    }
}

/// 実験ノートの背表紙（棚に並ぶ）
struct NotebookSpine: View {
    let experiment: Experiment
    let verdict: ExperimentResult.Verdict
    var index = 0

    var body: some View {
        let color = Palette.verdict(verdict)
        VStack(spacing: Space.s) {
            Rectangle()
                .fill(color.opacity(0.85))
                .frame(height: 10)
            Text(Self.verticalTitle(experiment.title))
                .font(.system(.caption, design: .serif).weight(.bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .padding(.vertical, Space.s)
                .frame(width: 30)
                .background(Palette.label)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                .edgeShadow()
            Spacer(minLength: 0)
            Hanko(verdict: verdict, size: 40, inProgress: false)
                .padding(.bottom, Space.s)
        }
        .frame(width: 58, height: 210)
        .background(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(index.isMultiple(of: 2) ? Palette.wood.soft : Palette.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1)
        )
        .paperShadow()
        .rotationEffect(.degrees(index.isMultiple(of: 3) ? -2 : (index.isMultiple(of: 2) ? 1.5 : 0)), anchor: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(experiment.title)、\(ResultText.headline(Analyzer.result(for: experiment)))")
    }

    /// 縦書き風に、1 文字ずつ改行（長いものは 9 文字で切る）
    static func verticalTitle(_ title: String) -> String {
        let chars = title.replacingOccurrences(of: " ", with: "").map(String.init)
        let cut = chars.count > 9 ? Array(chars.prefix(8)) + ["…"] : chars
        return cut.joined(separator: "\n")
    }
}

/// 記録表：実験の日ごとのマス。やる日＝朱・やすむ日＝藍、点数でマスの濃さが 5 段階、今日＝蛍光ペン
struct RecordTable: View {
    let experiment: Experiment
    let today: Int?
    var compact = false

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: compact ? 3 : 6), count: 7)
        LazyVGrid(columns: columns, spacing: compact ? 3 : 6) {
            ForEach(0..<experiment.duration, id: \.self) { day in
                RecordCell(experiment: experiment, day: day, isToday: day == today, compact: compact)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var summary: String {
        let recorded = experiment.checkIns.count
        return "記録表。\(experiment.duration) 日のうち \(recorded) 日を記録"
    }
}

struct RecordCell: View {
    let experiment: Experiment
    let day: Int
    let isToday: Bool
    var compact = false

    var body: some View {
        let checkIn = experiment.checkIn(day: day)
        let revealed = experiment.isRevealed(day: day)
        let arm = experiment.arm(day: day) ?? .doIt
        let swatch = Palette.swatch(for: arm)
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 3 : Radius.tag, style: .continuous)
                .fill(Palette.paper)
            RoundedRectangle(cornerRadius: compact ? 3 : Radius.tag, style: .continuous)
                .strokeBorder(Palette.grid, lineWidth: 1)
            if let checkIn {
                if checkIn.followed {
                    RoundedRectangle(cornerRadius: compact ? 3 : Radius.tag, style: .continuous)
                        .fill(swatch.accent.opacity(Palette.ratingOpacity(checkIn.rating)))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Hatch(color: swatch.accent.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 3 : Radius.tag, style: .continuous))
                }
                if !compact {
                    Text("\(checkIn.rating)")
                        .font(.system(.headline, design: .serif).weight(.bold).monospacedDigit())
                        .foregroundStyle(checkIn.followed && checkIn.rating >= 3 ? Color.white : Palette.ink)
                }
            } else if revealed {
                RoundedRectangle(cornerRadius: compact ? 3 : Radius.tag, style: .continuous)
                    .strokeBorder(swatch.accent, style: StrokeStyle(lineWidth: compact ? 1 : 1.5, dash: [3, 2]))
                if !compact {
                    Text(arm == .doIt ? "や" : "休")
                        .font(.system(.subheadline, design: .serif).weight(.bold))
                        .foregroundStyle(swatch.accent)
                }
            } else if !compact {
                Text("\(day + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft.opacity(0.7))
            }
            if isToday {
                RoundedRectangle(cornerRadius: compact ? 3 : Radius.tag, style: .continuous)
                    .strokeBorder(Palette.marker.accent, lineWidth: compact ? 2 : 3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: checkIn?.rating)
    }
}

/// 凡例
struct RecordLegend: View {
    var body: some View {
        HStack(spacing: Space.m) {
            item(Palette.shu.accent, "やる日")
            item(Palette.ai.accent, "やすむ日")
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.marker.accent, lineWidth: 2).frame(width: 12, height: 12)
                Text("今日")
            }
            HStack(spacing: 4) {
                Hatch(color: Palette.inkSoft).frame(width: 12, height: 12).clipShape(RoundedRectangle(cornerRadius: 2))
                Text("できなかった")
            }
        }
        .font(.caption2)
        .foregroundStyle(Palette.inkSoft)
        .accessibilityElement(children: .combine)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}

/// 紙吹雪の代わりの「紙片」：固定の乱数で毎回同じ散り方（記録したとき）
struct PaperBits: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false

    private struct Bit {
        let dx: CGFloat
        let dy: CGFloat
        let spin: Double
        let color: Color
        let size: CGFloat
    }

    private static let bits: [Bit] = {
        var rng = SplitMix64(state: 2026)
        let colors = [Palette.shu.accent, Palette.ai.accent, Palette.marker.accent, Palette.wood.accent]
        return (0..<24).map { i in
            let angle = Double(rng.next() % 360) * .pi / 180
            let distance = CGFloat(rng.next() % 90) + 60
            return Bit(
                dx: CGFloat(cos(angle)) * distance,
                dy: CGFloat(sin(angle)) * distance - 40,
                spin: Double(rng.next() % 720) + 180,
                color: colors[i % colors.count],
                size: CGFloat(rng.next() % 6) + 6
            )
        }
    }()

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<Self.bits.count, id: \.self) { i in
                    let bit = Self.bits[i]
                    Rectangle()
                        .fill(bit.color)
                        .frame(width: bit.size, height: bit.size * 0.6)
                        .rotationEffect(.degrees(burst ? bit.spin : 0))
                        .offset(x: burst ? bit.dx : 0, y: burst ? bit.dy + 120 : 0)
                        .opacity(burst ? 0 : 1)
                        .animation(.easeOut(duration: 1.1).delay(Double(i % 6) * 0.03), value: burst)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { burst = true }
    }
}
