import SwiftUI

// おみくじの筒：振ると、くじの棒が出る。今日の「やる日」「やすむ日」の割り付けになる。

/// 六角の筒（正面と左右の面、上の穴）
struct OmikujiTube: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let top = h * 0.1
            ZStack(alignment: .topLeading) {
                // 左右の面（暗い木）
                Path { p in
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
                .fill(Palette.wood.deep)
                // 正面
                Path { p in
                    p.addRect(CGRect(x: w * 0.18, y: top + h * 0.03, width: w * 0.64, height: h - top - h * 0.03))
                }
                .fill(Palette.wood.accent)
                // 木目
                Path { p in
                    for i in 0..<4 {
                        let x = w * (0.28 + CGFloat(i) * 0.14)
                        p.move(to: CGPoint(x: x, y: top + h * 0.08))
                        p.addCurve(
                            to: CGPoint(x: x + w * 0.02, y: h * 0.96),
                            control1: CGPoint(x: x - w * 0.03, y: h * 0.4),
                            control2: CGPoint(x: x + w * 0.05, y: h * 0.7)
                        )
                    }
                }
                .stroke(Palette.wood.deep.opacity(0.35), lineWidth: 1)
                // 上の面と穴
                Path { p in
                    p.move(to: CGPoint(x: 0, y: top))
                    p.addLine(to: CGPoint(x: w * 0.18, y: top - h * 0.05))
                    p.addLine(to: CGPoint(x: w * 0.82, y: top - h * 0.05))
                    p.addLine(to: CGPoint(x: w, y: top))
                    p.addLine(to: CGPoint(x: w * 0.82, y: top + h * 0.03))
                    p.addLine(to: CGPoint(x: w * 0.18, y: top + h * 0.03))
                    p.closeSubpath()
                }
                .fill(Palette.wood.decor)
                Ellipse()
                    .fill(Palette.ink.opacity(0.8))
                    .frame(width: w * 0.22, height: h * 0.035)
                    .position(x: w / 2, y: top - h * 0.01)
                // 正面の札「みくじ」
                Text("み\nく\nじ")
                    .font(.system(size: w * 0.17, weight: .heavy, design: .serif))
                    .foregroundStyle(Palette.shu.deep)
                    .lineSpacing(-4)
                    .padding(.vertical, 6)
                    .frame(width: w * 0.3)
                    .background(Palette.label)
                    .overlay(Rectangle().strokeBorder(Palette.shu.deep, lineWidth: 1.5).padding(2))
                    .position(x: w / 2, y: h * 0.52)
            }
        }
        .accessibilityHidden(true)
    }
}

/// くじの棒（先に色、やる／やすむの字）
struct KujiStick: View {
    let arm: Arm

    var body: some View {
        let swatch = Palette.swatch(for: arm)
        VStack(spacing: 0) {
            Text(arm == .doIt ? "や\nる" : "や\nす\nむ")
                .font(.system(size: 11, weight: .heavy, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(-3)
                .frame(width: 16, height: 46)
                .background(swatch.deep)
            Rectangle()
                .fill(Palette.wood.decor)
                .frame(width: 16, height: 70)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Palette.wood.deep.opacity(0.6), lineWidth: 0.8))
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

/// 今日のくじ。筒を押すと振って（左右の減衰する揺れ 0.65 秒）、棒が出る。
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
                        CubicKeyframe(16, duration: 0.09)
                        CubicKeyframe(-14, duration: 0.11)
                        CubicKeyframe(11, duration: 0.11)
                        CubicKeyframe(-8, duration: 0.1)
                        CubicKeyframe(5, duration: 0.09)
                        CubicKeyframe(-2, duration: 0.07)
                        CubicKeyframe(0, duration: 0.08)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: draw)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(revealed ? "今日のくじ：\(arm.title)" : "おみくじの筒。押すと今日のくじを引きます")
                .accessibilityAddTraits(revealed ? [] : .isButton)
                .accessibilityAction { draw() }
                .haptic(.impact(weight: .medium), trigger: shakes)
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
            try? await Task.sleep(for: .milliseconds(680))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.58)) { onDraw() }
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
            case .left: 14
            case .right: -12
            case .left2: 7
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
                case .left, .right, .left2: .easeInOut(duration: 0.13)
                case .out: .spring(response: 0.5, dampingFraction: 0.58)
                case .hold: .easeInOut(duration: 1.4)
                }
            }
        }
    }
}
