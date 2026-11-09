import SwiftUI

/// 設定：Pro・書き出し・手応えと見た目・しくみ・プライバシー
struct SettingsView: View {
    @Environment(ExperimentStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @AppStorage("haptics") private var haptics = true
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("onboarded") private var onboarded = true
    @State private var paywall: PaywallReason?
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    proPanel
                    Panel {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionTitle(text: "手応えと見た目")
                            Toggle("振動", isOn: $haptics).tint(Palette.sky.deep)
                            Text("カードをめくる・点数を選ぶときと、記録した・カードを手に入れたときに、軽く震えます。")
                                .font(.caption).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            Picker("見た目", selection: $appearance) {
                                Text("自動").tag(0)
                                Text("ライト").tag(1)
                                Text("ダーク").tag(2)
                            }
                            .pickerStyle(.segmented)
                            Text("音は鳴りません。消音のままでも同じように使えます。通知も使いません（朝にアプリを開いて、カードをめくる形です）。")
                                .font(.caption).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionTitle(text: "しくみ")
                            Text(HowItWorks.text)
                                .font(.footnote)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                onboarded = false
                            } label: {
                                Label("使い方をもう一度見る", systemImage: "play.rectangle")
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionTitle(text: "プライバシー")
                            Text("記録はこの iPhone の中（アプリの設定領域）だけに保存し、外には送りません。アカウント・広告・解析はありません。Apple Intelligence を使う場合も、端末の中のモデルだけです。アプリを消すと記録も消えます。")
                                .font(.footnote)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("医療の判断には使わないでください。体調に関わることは医師に相談してください。")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Space.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("設定")
            .sheet(item: $paywall) { reason in
                PaywallView(reason: reason)
            }
        }
    }

    private var proPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    SectionTitle(text: "じぶん実験室 Pro")
                    if purchases.isPro {
                        Image(systemName: "checkmark.seal").foregroundStyle(Palette.sky.deep)
                    }
                }
                if purchases.isPro {
                    Text("Pro が使えます：実験を 3 つ同時に・追加の型 \(TemplateLibrary.proCount)・追試の合わせた判定・記録の書き出し。")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("実験を 3 つ同時に・追加の型 \(TemplateLibrary.proCount)・追試の合わせた判定・記録の書き出し（買い切り）。")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { paywall = .settings } label: { Label("Pro を見る", systemImage: "sparkles") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                if purchases.isPro {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("記録を書き出す（CSV）", systemImage: "tablecells")
                        }
                        .buttonStyle(QuietButtonStyle(color: Palette.sky.deep))
                    } else {
                        Text("書き出す記録がまだありません。")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                } else {
                    Button { paywall = .export } label: { Label("記録を書き出す（CSV · Pro）", systemImage: "lock") }
                        .buttonStyle(QuietButtonStyle(color: Palette.inkSoft))
                    Button("購入を復元") {
                        Task { await purchases.restore() }
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.sky.deep)
                }
            }
        }
        .task(id: purchases.isPro) { prepareExport() }
    }

    private func prepareExport() {
        guard purchases.isPro, store.experiments.contains(where: { !$0.checkIns.isEmpty }) else {
            exportURL = nil
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jibun-lab-records.csv")
        do {
            try CSVExport.text(store.experiments, calendar: store.calendar).write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
        } catch {
            exportURL = nil
        }
    }
}

enum HowItWorks {
    static let text = """
    1. 期間（8 日か 14 日）の半分を「やる日」、半分を「やすむ日」にし、順番をくじで決めます（同じ側は 3 日まで）。毎朝カードをめくると、その日がどちらかが分かります。
    2. 毎日、同じ質問に 1〜5 で答えます。
    3. 最後の日まで結果は伏せます（途中で何度も見ると、偶然の波を「効果」と見まちがえやすいため）。
    4. やる日とやすむ日の平均をくらべ、くじの割り付けを全部の組み合わせで入れ替えて、同じくらいの差が出る割合（並べ替え検定）を出します。
    5. 割合が 10% 以下で平均の差が 0.5 以上なら「効いた」か「逆効果」、そうでなければ「思い込みだった」のカード。★は割合が 1% 以下で 3、5% 以下で 2。
    """
}

enum Appearance {
    static func scheme(_ value: Int) -> ColorScheme? {
        switch value {
        case 1: .light
        case 2: .dark
        default: nil
        }
    }
}
