import SwiftUI
import UIKit

// 見た目の決まり（.claude/skills/app-quality-bar/references/look.md §2〜4）。
// 世界観：理科の実験ノート（方眼の記録用紙）・おみくじの筒・ハンコ。
// 色はここだけで決める。1 色ごとに accent / soft / deep / paper / decor の 5 段階。ライトとダークの両方を持つ。

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// ライトとダークで変わる色
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// 1 色の 5 段階
struct Swatch: Sendable {
    /// 主
    let accent: Color
    /// 淡い地
    let soft: Color
    /// 白い文字が読める濃さ（白い文字を載せるボタンは必ずこれ）
    let deep: Color
    /// 紙の地
    let paper: Color
    /// 飾り（ラベルの帯・テープ）
    let decor: Color
}

enum Palette {
    // 紙とインク（真っ白・真っ黒にしない）
    static let desk = Color(light: 0xECE7DC, dark: 0x131417)
    static let paper = Color(light: 0xFBF9F3, dark: 0x1F2024)
    static let grid = Color(light: 0xD5E1E6, dark: 0x2B333A)
    static let margin = Color(light: 0xE8A19C, dark: 0x6B3A38)
    static let ink = Color(light: 0x2A3038, dark: 0xECE6D8)
    static let inkSoft = Color(light: 0x6F7884, dark: 0xA39C8E)
    static let line = Color(light: 0xDCD5C5, dark: 0x3A3C42)
    static let label = Color(light: 0xFFFEFA, dark: 0x2A2B30)
    static let clip = Color(light: 0x9AA3AC, dark: 0x7C848C)

    /// やる日＝朱（ハンコの朱肉）
    static let shu = Swatch(
        accent: Color(light: 0xE0533D, dark: 0xEE6E58),
        soft: Color(light: 0xFBE1D9, dark: 0x3D2420),
        deep: Color(light: 0xB5341F, dark: 0xC2452F),
        paper: Color(light: 0xFFF5F0, dark: 0x2A1F1D),
        decor: Color(light: 0xF5C6A5, dark: 0x7A4E3A)
    )

    /// やすむ日＝藍
    static let ai = Swatch(
        accent: Color(light: 0x3F6FB0, dark: 0x7FA3D9),
        soft: Color(light: 0xDEE8F5, dark: 0x1D2737),
        deep: Color(light: 0x284F8A, dark: 0x3F6FB0),
        paper: Color(light: 0xF4F7FC, dark: 0x1C212A),
        decor: Color(light: 0xBDD2EC, dark: 0x3B4E6B)
    )

    /// 今日＝蛍光ペン
    static let marker = Swatch(
        accent: Color(light: 0xF2C63A, dark: 0xD9B232),
        soft: Color(light: 0xFCEFB3, dark: 0x4A4220),
        deep: Color(light: 0x8A6A00, dark: 0xF2C63A),
        paper: Color(light: 0xFFFBEA, dark: 0x29261A),
        decor: Color(light: 0xF7DE85, dark: 0x6B5B22)
    )

    /// おみくじの筒（木）
    static let wood = Swatch(
        accent: Color(light: 0xCFA470, dark: 0x9C7A4F),
        soft: Color(light: 0xF1E3CF, dark: 0x3A2F22),
        deep: Color(light: 0x9B6E3C, dark: 0x6E5132),
        paper: Color(light: 0xFAF3E8, dark: 0x2A251E),
        decor: Color(light: 0xE6C9A0, dark: 0x7C6240)
    )

    static func swatch(for arm: Arm) -> Swatch {
        arm == .doIt ? shu : ai
    }

    /// 結果の色：効果あり＝朱、逆効果＝藍、差なし＝墨、途中＝鉛筆
    static func verdict(_ verdict: ExperimentResult.Verdict) -> Color {
        switch verdict {
        case .better: shu.deep
        case .worse: ai.deep
        case .noClearDifference: ink
        case .notEnough: inkSoft
        }
    }

    /// 記録の点数（1〜5）で、マスの濃さを 5 段階に
    static func ratingOpacity(_ rating: Int) -> Double {
        let tiers = [0.28, 0.45, 0.62, 0.8, 1.0]
        return tiers[min(max(rating, 1), 5) - 1]
    }
}

/// 書体：見出しと数字はセリフ、本文はゴシック（2 書体）
enum Typo {
    static func title(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.bold)
    }

    static func number(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold).monospacedDigit()
    }

    /// 小さなラベル（字間を開けて使う）
    static let tag = Font.caption2.weight(.semibold)
}

/// 角丸の段階
enum Radius {
    static let tag: CGFloat = 4
    static let tile: CGFloat = 8
    static let button: CGFloat = 12
    static let page: CGFloat = 18
}

/// 余白の段階
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// 影は 3 種類だけ
extension View {
    /// 紙（ふだん）
    func paperShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    /// 浮いた物（札・ハンコ・結果カード）
    func liftedShadow() -> some View {
        shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
    }

    /// 線の影（ラベル・小さな札の厚み）
    func edgeShadow() -> some View {
        shadow(color: Palette.line, radius: 0, x: 0, y: 1)
    }
}

/// 主なボタン：判子調の四角。下辺だけ太い線で押せるキーに見せ、押すと沈む
struct StampButtonStyle: ButtonStyle {
    var swatch: Swatch = Palette.shu
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.l)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(isEnabled ? swatch.deep : Palette.inkSoft.opacity(0.5))
            )
            .background(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                    .offset(y: pressed ? 1 : 4)
            )
            .offset(y: pressed ? 3 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

/// 控えめなボタン：鉛筆の線で囲った札
struct PencilButtonStyle: ButtonStyle {
    var color: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, Space.m)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Palette.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(color.opacity(0.55), lineWidth: 1.2)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 振動。設定で切れる（手応えの表は README）
struct HapticModifier<T: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: T
    @AppStorage("haptics") private var enabled = true

    func body(content: Content) -> some View {
        let on = enabled
        let feedback = feedback
        return content.sensoryFeedback(trigger: trigger) { _, _ in on ? feedback : nil }
    }
}

extension View {
    func haptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger))
    }
}

/// 横揺れ（失敗・間違い）。0,-8,7,-5,4,-2,0 のように減衰する
struct ShakeEffect: GeometryEffect {
    var phase: CGFloat
    var travel: CGFloat = 8

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = phase - phase.rounded(.down)
        let decay = 1 - progress
        let x = travel * decay * sin(progress * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// 0.6 → 1 のバネで出てくる（結果・ハンコ）。動きを減らす設定ではそのまま出す
struct PopIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shown = true }
            }
    }
}

extension View {
    func popIn() -> some View { modifier(PopIn()) }
}

/// 小さなラベル（字間を開ける）
struct TagText: View {
    let text: String
    var color: Color = Palette.inkSoft

    var body: some View {
        Text(text)
            .font(Typo.tag)
            .kerning(0.6)
            .foregroundStyle(color)
    }
}
