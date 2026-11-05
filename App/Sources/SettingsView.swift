import SwiftUI

/// 設定：振動・見た目・使い方・しくみ・プライバシー（音と通知は使わない理由も書く）
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("haptics") private var haptics = true
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("onboarded") private var onboarded = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    NotebookPage(showsClip: false) {
                        VStack(alignment: .leading, spacing: Space.m) {
                            LabelSticker(text: "手応えと見た目", color: Palette.ai.accent, font: Typo.title(.headline))
                            Toggle("振動", isOn: $haptics).tint(Palette.ai.deep)
                            Text("くじを引く・点数を選ぶ・記録する・ハンコが押されるときに震えます。")
                                .font(.caption).foregroundStyle(Palette.inkSoft)
                            Picker("見た目", selection: $appearance) {
                                Text("自動").tag(0)
                                Text("ライト").tag(1)
                                Text("ダーク").tag(2)
                            }
                            .pickerStyle(.segmented)
                            Text("音は鳴りません。静かな記録の道具として、消音のままでも同じように使えるようにしています。")
                                .font(.caption).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("通知は使いません。朝にアプリを開いてくじを引く形にしています。")
                                .font(.caption).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    NotebookPage(showsClip: false) {
                        VStack(alignment: .leading, spacing: Space.m) {
                            LabelSticker(text: "しくみ", color: Palette.shu.accent, font: Typo.title(.headline))
                            Text("1. 期間の半分を「やる日」、半分を「やすむ日」にし、順番をくじで決めます（同じ側は 3 日まで）。\n2. 毎日、同じ質問に 1〜5 で答えます。\n3. やる日とやすむ日の平均をくらべ、くじの割り付けを全通り入れ替えたときに、同じくらいの差が出る割合（並べ替え検定）を出します。\n4. 割合が 10% 以下で、平均の差が 0.5 以上なら「効果あり」のハンコ。")
                                .font(.footnote)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                onboarded = false
                                dismiss()
                            } label: {
                                Label("使い方をもう一度見る", systemImage: "play.rectangle")
                            }
                            .buttonStyle(PencilButtonStyle())
                        }
                    }
                    NotebookPage(showsClip: false) {
                        VStack(alignment: .leading, spacing: Space.m) {
                            LabelSticker(text: "プライバシー", color: Palette.marker.accent, font: Typo.title(.headline))
                            Text("記録はこの iPhone の中（アプリの設定領域）だけに保存し、外には送りません。アカウント・広告・解析はありません。Apple Intelligence も端末の中のモデルだけを使います。アプリを消すと記録も消えます。")
                                .font(.footnote)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("医療の判断には使わないでください。体調に関わることは医師に相談してください。")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.shu.deep)
                        }
                    }
                }
                .padding(Space.l)
                .padding(.top, Space.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.desk.ignoresSafeArea())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
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
