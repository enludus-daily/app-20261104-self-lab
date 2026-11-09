import SwiftUI
import UIKit

// 見た目の決まり（.claude/skills/app-quality-bar/references/look.md §0〜4）。
// 世界観：習慣がトレーディングカードになる。伏せたカードをめくってくじを引き、結果の強さが★と箔（ホロ）になる。
// トーンは StudyReel：ほぼ白の地、淡い sky が 1 系統の主色、差し色は peach、セリフの見出しと数字、細い線、弱い影。
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
    /// 主（広い面・帯・グラフ）
    let accent: Color
    /// 淡い地（選択中・札の地）
    let soft: Color
    /// 白い文字が読める濃さ（白い文字を載せるボタンと小さな文字だけ）
    let deep: Color
    /// カードの地
    let paper: Color
    /// 飾り（箔のきらめき・カードの裏の模様）
    let decor: Color
}

enum Palette {
    // 地と文字（StudyReel：ほぼ白の地・真っ黒にしない文字・細い線）
    static let ground = Color(light: 0xF3F6F9, dark: 0x111417)
    static let card = Color(light: 0xFCFDFE, dark: 0x1B1F23)
    static let ink = Color(light: 0x2E3A46, dark: 0xE6EAEE)
    static let inkSoft = Color(light: 0x8E9AA6, dark: 0x8E9AA6)
    static let line = Color(light: 0xE3E9EF, dark: 0x2C3238)
    static let field = Color(light: 0xFFFFFF, dark: 0x23282D)

    /// 主の 1 系統＝sky（やすむ日・ボタン・カードの裏・思い込みだったカード）
    static let sky = Swatch(
        accent: Color(light: 0x9EC3E2, dark: 0x6F96B8),
        soft: Color(light: 0xE1EDF6, dark: 0x1E2A35),
        deep: Color(light: 0x5E8DB8, dark: 0x5A87B0),
        paper: Color(light: 0xF5F9FC, dark: 0x1A2028),
        decor: Color(light: 0xCFE0EE, dark: 0x34475A)
    )

    /// 差し色＝peach（やる日・効いたカード）
    static let peach = Swatch(
        accent: Color(light: 0xF4BBA4, dark: 0xC98E78),
        soft: Color(light: 0xFCE9E1, dark: 0x3A2A24),
        deep: Color(light: 0xC0785E, dark: 0xB8735A),
        paper: Color(light: 0xFFF8F4, dark: 0x241D1A),
        decor: Color(light: 0xF8D6C8, dark: 0x5A4036)
    )

    /// 霧（逆効果のカード・まだの印）。sky に寄せた無彩色に近い色
    static let mist = Swatch(
        accent: Color(light: 0xC9D6E2, dark: 0x4A5A6A),
        soft: Color(light: 0xEEF3F7, dark: 0x20262C),
        deep: Color(light: 0x5E6B78, dark: 0xA9B6C3),
        paper: Color(light: 0xF7F9FB, dark: 0x1A1D21),
        decor: Color(light: 0xDCE5ED, dark: 0x333B44)
    )

    static func swatch(for arm: Arm) -> Swatch {
        arm == .doIt ? peach : sky
    }

    static func swatch(for kind: CardKind) -> Swatch {
        switch kind {
        case .proven: peach
        case .myth: sky
        case .backfire: mist
        }
    }

    /// 記録の点数（1〜5）で、印の濃さを 5 段階に
    static func ratingOpacity(_ rating: Int) -> Double {
        let tiers = [0.28, 0.45, 0.62, 0.8, 1.0]
        return tiers[min(max(rating, 1), 5) - 1]
    }
}

/// 書体：見出しと数字はセリフ、本文はゴシック（2 書体）
enum Typo {
    static func title(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.medium)
    }

    /// 大きな数字（字間を -3 に詰めて使う）
    static func number(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.regular).monospacedDigit()
    }

    /// 小さなラベル（字間を開けて使う）
    static let tag = Font.caption2.weight(.medium)
}

/// 角丸の段階（すべて continuous）
enum Radius {
    static let tag: CGFloat = 6
    static let tile: CGFloat = 12
    static let button: CGFloat = 14
    static let card: CGFloat = 18
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

/// 影は弱く 3 種類だけ
extension View {
    /// ふだんの面
    func softShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    /// 手に持ったカード
    func liftedShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    /// めくっている最中・重ねたカードの一番上
    func floatingShadow() -> some View {
        shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
    }
}

/// 主なボタン：deep の面に白い文字。押すと少しだけ縮んで薄くなる
struct PrimaryButtonStyle: ButtonStyle {
    var swatch: Swatch = Palette.sky
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.subheadline.weight(.semibold))
            .kerning(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.l)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(isEnabled ? swatch.deep : Palette.inkSoft.opacity(0.45))
            )
            .opacity(pressed ? 0.85 : 1)
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: pressed)
    }
}

/// 控えめなボタン：細い線で囲った札
struct QuietButtonStyle: ButtonStyle {
    var color: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, Space.m)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(color.opacity(0.35), lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// 面（カードより一段弱い入れ物）。白に近い地・細い線・弱い影
struct Panel<Content: View>: View {
    var padding: CGFloat = Space.l
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
            .softShadow()
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

/// そっと置く：少し大きい所から 0.35 秒で下りて、薄い所から現れる。動きを減らす設定ではそのまま出す
struct PopIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 1.04)
            .opacity(shown || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.35)) { shown = true }
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

/// 見出し（セリフ・字間）
struct SectionTitle: View {
    let text: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(Typo.title(.title3))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: Space.s)
            if let detail {
                TagText(text: detail)
            }
        }
        .textCase(nil)
    }
}

/// ★の列
struct StarRow: View {
    let stars: Int
    var max: Int = 3
    var color: Color = Palette.peach.deep
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<max, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(index < stars ? color : Palette.inkSoft.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("証拠の強さ ★\(stars)")
    }
}
