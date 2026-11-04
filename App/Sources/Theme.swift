import SwiftUI

/// 見た目の決まり（色・角丸・影）。アイコンの青緑〜すみれ色に合わせる。
enum Theme {
    static let teal = Color(red: 0.05, green: 0.62, blue: 0.60)
    static let violet = Color(red: 0.45, green: 0.36, blue: 0.88)
    static let amber = Color(red: 1.0, green: 0.71, blue: 0.22)
    static let rose = Color(red: 0.92, green: 0.36, blue: 0.42)

    static let brand = LinearGradient(colors: [teal, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let corner: CGFloat = 22

    static func color(for arm: Arm) -> Color {
        arm == .doIt ? teal : violet
    }

    static func symbol(for arm: Arm) -> String {
        arm == .doIt ? "bolt.fill" : "moon.zzz.fill"
    }

    /// 画面の背景（上に淡い色）
    static func background(_ scheme: ColorScheme) -> LinearGradient {
        let top = scheme == .dark ? Color(red: 0.07, green: 0.14, blue: 0.16) : Color(red: 0.88, green: 0.96, blue: 0.95)
        let bottom = scheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.08) : Color(red: 0.97, green: 0.97, blue: 0.99)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .center)
    }
}

/// カード
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(scheme == .dark ? Color(white: 0.13) : Color.white)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 12, y: 4)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// 押すと少し縮むボタン（主な操作）
struct BrandButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.brand)
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? fill : AnyShapeStyle(Color.gray.opacity(0.35)))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// 控えめなボタン
struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.teal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.22 : 0.12)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// やる日・やすむ日の札
struct ArmBadge: View {
    let arm: Arm
    var large = false

    var body: some View {
        Label(arm.title, systemImage: Theme.symbol(for: arm))
            .font(large ? .title2.weight(.heavy) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, large ? 16 : 8)
            .padding(.vertical, large ? 8 : 4)
            .background(Capsule().fill(Theme.color(for: arm)))
    }
}

/// 紙吹雪（記録したとき・結果が出たとき）
struct Confetti: View {
    @State private var fall = false
    private let pieces: [(x: CGFloat, delay: Double, color: Color, size: CGFloat)] = (0..<32).map { i in
        let colors = [Theme.teal, Theme.violet, Theme.amber, Theme.rose]
        return (x: CGFloat((i * 37) % 100) / 100, delay: Double(i % 8) * 0.07, color: colors[i % colors.count], size: CGFloat(6 + (i % 4) * 2))
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<pieces.count, id: \.self) { i in
                let piece = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.6)
                    .rotationEffect(.degrees(fall ? Double(i * 47) : 0))
                    .position(x: piece.x * proxy.size.width, y: fall ? proxy.size.height + 20 : -20)
                    .animation(.easeIn(duration: 1.6).delay(piece.delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fall = true }
    }
}

/// 実験の日ごとのマス目（記録した日は数字、今日は枠）
struct DayGrid: View {
    let experiment: Experiment
    let today: Int?
    var compact = false

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: compact ? 4 : 8), count: 7)
        LazyVGrid(columns: columns, spacing: compact ? 4 : 8) {
            ForEach(Array(experiment.schedule.enumerated()), id: \.offset) { day, arm in
                cell(day: day, arm: arm)
            }
        }
    }

    @ViewBuilder
    private func cell(day: Int, arm: Arm) -> some View {
        let checkIn = experiment.checkIn(day: day)
        let revealed = experiment.isRevealed(day: day)
        let color = revealed ? Theme.color(for: arm) : Color.secondary
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 4 : 10, style: .continuous)
                .fill(checkIn != nil ? color.opacity(checkIn?.followed == false ? 0.35 : 1) : color.opacity(0.12))
            if day == today {
                RoundedRectangle(cornerRadius: compact ? 4 : 10, style: .continuous)
                    .strokeBorder(Theme.amber, lineWidth: compact ? 1.5 : 3)
            }
            if !compact {
                if let checkIn {
                    Text("\(checkIn.rating)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                } else if revealed {
                    Image(systemName: Theme.symbol(for: arm))
                        .font(.caption)
                        .foregroundStyle(color)
                } else {
                    Text("\(day + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(day: day, arm: arm, checkIn: checkIn, revealed: revealed))
    }

    private func accessibilityText(day: Int, arm: Arm, checkIn: CheckIn?, revealed: Bool) -> String {
        var text = "\(day + 1) 日目"
        if revealed { text += "、\(arm.title)" }
        if let checkIn { text += "、記録 \(checkIn.rating)" + (checkIn.followed ? "" : "、くじのとおりにできなかった") }
        return text
    }
}
