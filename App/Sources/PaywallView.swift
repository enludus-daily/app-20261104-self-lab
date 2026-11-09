import SwiftUI
import StoreKit

/// 課金の画面を開いた理由（価値を感じた直後か、無料の上限に届いたときだけ。起動時には出さない）
enum PaywallReason: String, Identifiable {
    case afterCard, moreExperiments, proTemplate, replication, export, settings

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .afterCard: "カードを、もっと確かに"
        case .moreExperiments: "実験を、3 つ同時に"
        case .proTemplate: "追加の型で、図鑑を 66 枠に"
        case .replication: "追試で、偶然を見分ける"
        case .export: "記録を、自分の手で分析"
        case .settings: "じぶん実験室 Pro"
        }
    }
}

struct PaywallView: View {
    let reason: PaywallReason
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: PurchaseOutcome?
    @State private var isBuying = false
    @State private var restored = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    header
                    VStack(spacing: Space.m) {
                        ForEach(ProFeature.allCases) { feature in
                            row(feature)
                        }
                    }
                    priceBlock
                    Text("Pro は買い切りです。一度買えば、この Apple アカウントのほかの iPhone と家族共有でも使えます。核の機能（くじ・記録・結果・図鑑の \(TemplateLibrary.freeCount) 枠）はずっと無料です。")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                if purchases.loadState == .idle { await purchases.load() }
            }
            .haptic(.success, trigger: purchases.isPro)
        }
    }

    private var header: some View {
        VStack(spacing: Space.m) {
            ZStack {
                CardBack(width: 52)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -30, y: 4)
                CardBack(width: 52)
                    .rotationEffect(.degrees(10))
                    .offset(x: 30, y: 4)
                CardBack(width: 58)
                    .liftedShadow()
            }
            .frame(height: CardMetrics.height(for: 58) + 8)
            .accessibilityHidden(true)
            TagText(text: "じぶん実験室 Pro", color: Palette.sky.deep)
            Text(reason.headline)
                .font(Typo.title(.title2))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
        }
    }

    private func row(_ feature: ProFeature) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: feature.symbol)
                .font(.body.weight(.light))
                .foregroundStyle(Palette.sky.deep)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Palette.sky.soft))
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(feature.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.6))
    }

    @ViewBuilder
    private var priceBlock: some View {
        VStack(spacing: Space.m) {
            if purchases.isPro {
                Label("Pro になっています。ありがとうございます。", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.sky.deep)
            } else if let product = purchases.proProduct {
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    Text(product.displayPrice)
                        .font(Typo.number(.largeTitle))
                        .kerning(-2)
                        .foregroundStyle(Palette.ink)
                    Text("買い切り")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                }
                Button {
                    buy(product)
                } label: {
                    if isBuying {
                        ProgressView().tint(.white)
                    } else {
                        Text("Pro にする")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isBuying)
            } else if purchases.loadState == .loading || purchases.loadState == .idle {
                ProgressView("価格を読み込んでいます")
                    .font(.footnote)
            } else {
                Button {} label: { Text("Pro にする") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
                Text("いまは App Store から価格を読み込めません。通信を確かめて、あとでもう一度開いてください。")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("もう一度読み込む") {
                    Task { await purchases.load() }
                }
                .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
            }
            if let message = outcomeMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            if !purchases.isPro {
                Button {
                    Task {
                        await purchases.restore()
                        restored = true
                    }
                } label: {
                    Text(restored ? "復元を確かめました" : "購入を復元")
                }
                .font(.footnote)
                .foregroundStyle(Palette.sky.deep)
            }
        }
    }

    private var outcomeMessage: String? {
        switch outcome {
        case .pending: "購入の承認を待っています。承認されると Pro になります。"
        case .failed: "購入できませんでした。時間をおいて、もう一度お試しください。"
        case .cancelled, .purchased, nil: nil
        }
    }

    private func buy(_ product: Product) {
        isBuying = true
        Task {
            outcome = await purchases.purchase(product)
            isBuying = false
        }
    }
}
