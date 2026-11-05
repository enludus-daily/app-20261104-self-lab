import SwiftUI

// おみくじの筒：振ると、くじの棒が出る。今日の「やる日」「やすむ日」の割り付けになる。

/// 六角の筒（淡い面と細い線）
struct OmikujiTube: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let top = h * 0.1
            let stroke = StrokeStyle(lineWidth: 0.8, lineJoin: .round)
            let sides = Path { p in
                p.move(to: CGPoint(x: 0, y: top))
                p.addLine(to: CGPoint(x: w * 0.18, y: top + h * 0.03))
                p.addLine(to: CGPoint(x: w * 0.18, y: h))
                p.addLine(to: CGPoint(x: 0, y: h - h * 0.03))
                p.closeSubpath()
                p.move(to: CGPoint(x: w, y: top))
                p.addLine(to: CGPoint(x: w * 0.82, y: top + h * 0.03))
                p.addLine(to: CGPoint(x: w * 0.82, y: h))
                p.addLine(to: CGPoint(x: w, y: h - h * 0.03))
                p.closeSubpath()
            }
            let front = Path(CGRect(x: w * 0.18, y: top + h * 0.03, width: w * 0.64, height: h - top - h * 0.03))
            let lid = Path { p in
                p.move(to: CGPoint(x: 0, y: top))
                p.addLine(to: CGPoint(x: w * 0.18, y: top - h * 0.05))
                p.addLine(to: CGPoint(x: w * 0.82, y: top - h * 0.05))
                p.addLine(to: CGPoint(x: w, y: top))
                p.addLine(to: CGPoint(x: w * 0.82, y: top + h * 0.03))
                p.addLine(to: CGPoint(x: w * 0.18, y: top + h * 0.03))
                p.closeSubpath()
            }
            ZStack(alignment: .topLeading) {
                sides.fill(Palette.stone.accent)
                sides.stroke(Palette.stone.deep.opacity(0.7), style: stroke)
                front.fill(Palette.stone.paper)
                front.stroke(Palette.stone.deep.opacity(0.7), style: stroke)
                lid.fill(Palette.stone.soft)
                lid.stroke(Palette.stone.deep.opacity(0.7), style: stroke)
                Ellipse()
                    .fill(Palette.ink.opacity(0.45))
                    .frame(width: w * 0.2, height: h * 0.03)
                    .position(x: w / 2, y: top - h * 0.01)
                // 正面の札「みくじ」
                Text("み\nく\nじ")
                    .font(.system(size: w * 0.14, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.sky.deep)
                    .lineSpacing(-2)
                    .padding(.vertical, 6)
                    .frame(width: w * 0.28)
                    .background(Palette.label)
                    .overlay(Rectangle().strokeBorder(Palette.sky.deep.opacity(0.6), lineWidth: 0.6).padding(2))
                    .position(x: w / 2, y: h * 0.52)
            }
        }
        .accessibilityHidden(true)
    }
}

/// くじの棒（先に淡い色、やる／やすむの字）
struct KujiStick: View {
    let arm: Arm

    var body: some View {
        let swatch = Palette.swatch(for: arm)
        VStack(spacing: 0) {
            Text(arm == .doIt ? "や\nる" : "や\nす\nむ")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(swatch.deep)
                .lineSpacing(-3)
                .frame(width: 14, height: 44)
                .background(swatch.accent.opacity(0.6))
            Rectangle()
                .fill(Palette.stone.paper)
                .frame(width: 14, height: 70)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Palette.stone.deep.opacity(0.6), lineWidth: 0.6))
        .accessibilityHidden(true)
    }
}

/// 筒＋棒。shakeTrigger が変わると揺れ、revealed で棒がせり上がる
struct OmikujiAssembly: View {
    let arm: Arm
    let revealed: Bool
    var angle: Double = 0
    var width: CGFloat = 92

    var body: some View {
        let height = width * 1.75
        ZStack(alignment: .top) {
            KujiStick(arm: arm)
                .offset(y: revealed ? -height * 0.42 : height * 0.12)
                .opacity(revealed ? 1 : 0)
            OmikujiTube()
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(angle), anchor: .bottom)
        .padding(.top, height * 0.42)
    }
}

/// 今日のくじ。筒を押すと少し浮いて小さく揺れ（数度・0.5 秒）、棒がそっと出る。
struct LotteryBox: View {
    let arm: Arm
    let revealed: Bool
    /// 外のボタンから振るとき、この数を増やす
    var drawRequest = 0
    var width: CGFloat = 92
    let onDraw: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0
    @State private var drawing = false

    var body: some View {
        OmikujiAssembly(arm: arm, revealed: revealed, width: width)
                .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, angle in
                    content.rotationEffect(.degrees(angle), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(3, duration: 0.12)
                        CubicKeyframe(-3, duration: 0.14)
                        CubicKeyframe(2, duration: 0.12)
                        CubicKeyframe(0, duration: 0.12)
                    }
                }
                .scaleEffect(drawing ? 1.05 : 1)
                .animation(.easeOut(duration: 0.25), value: drawing)
                .contentShape(Rectangle())
                .onTapGesture(perform: draw)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(revealed ? "今日のくじ：\(arm.title)" : "おみくじの筒。押すと今日のくじを引きます")
                .accessibilityAddTraits(revealed ? [] : .isButton)
                .accessibilityAction { draw() }
                .onChange(of: drawRequest) { _, _ in draw() }
    }

    private func draw() {
        guard !revealed, !drawing else { return }
        if reduceMotion {
            onDraw()
            return
        }
        drawing = true
        shakes += 1
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            withAnimation(.easeOut(duration: 0.35)) { onDraw() }
            drawing = false
        }
    }
}

/// オンボーディングの動く見本：振る→棒が出る→待つ、をくり返す。動きを減らす設定では止まった絵
struct OmikujiDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: CaseIterable {
        case rest, left, right, left2, out, hold

        var angle: Double {
            switch self {
            case .left: 3
            case .right: -3
            case .left2: 2
            default: 0
            }
        }
    }

    var body: some View {
        if reduceMotion {
            OmikujiAssembly(arm: .doIt, revealed: true)
        } else {
            PhaseAnimator(Step.allCases) { step in
                OmikujiAssembly(arm: .doIt, revealed: step == .out || step == .hold, angle: step.angle)
            } animation: { step in
                switch step {
                case .rest: .easeInOut(duration: 0.9)
                case .left, .right, .left2: .easeInOut(duration: 0.16)
                case .out: .easeOut(duration: 0.35)
                case .hold: .easeInOut(duration: 1.4)
                }
            }
        }
    }
}
