# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.002 |
| アプリ名 | じぶん実験室 - 習慣を確かめてカードに（2026-11-09 の作り直しで変更。ホーム画面の表示名は「じぶん実験室」。AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261104-self-lab/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261104-self-lab/blob/main/PRIVACY.md |
| 年齢区分の答え | 暴力・性的表現・ギャンブル・Web 閲覧・ユーザー間のやりとり：すべて「なし」。医療・治療の情報：「なし」（習慣を比べるだけで、医療の判断には使わないと表示）。生成 AI：対応端末でだけ、端末の中のモデルで実験の案（短い文）を作る（脇の機能）。出力は医療・服薬・食事制限の語を除いている。→ 4+ の見込み。API では入れないので本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・タイマー・占いなどではない。日ごとのくじで割り付けて比べ、並べ替え検定で結果を出す自己実験の道具。くじは占いではなく比べるための割り付け（説明文と画面にそう書いている）。カードは結果の表示で、ガチャ（お金で引くくじ）ではない。課金は買い切りの Pro だけ。
- 既存のアプリとの意味のある違い：習慣アプリは続けた日を数えるだけ。これはくじで「やる日・やすむ日」を割り付けて比べ、自分に効いたかを数字と言葉で示す。端末の中だけで完結。
- 長く使える価値（4.2）：実験を終えるたびに「あなたに効くこと」が積み上がり、次の実験へ続く。
- 他社の名前・商標・見た目を使っていないか：使っていない。アイコンは自作（Pillow で描画）、SF Symbols のみ。
- Apple Intelligence を使う場合、使えない端末での動き：`SystemLanguageModel.availability` と日本語の対応を確かめ、使えないときは理由を表示し、組み込みの 42 の型から選べる。モデルが失敗したときも型に切り替える。
- 健康に関わる表現（1.4.1）：診断・治療をうたわない。実験の型はスマホ・歩く・光・片付けなどの日常の習慣だけ。「医療の判断には使わない」を作る画面・結果の画面・説明文に表示。

## 収益の道筋

- 買い切りの Pro ¥600（`com.enludus.daily.002.pro`、家族共有あり）。理由と勝算の表は README の「課金」。商品は `asc.yml` の `products` で作る（審査への提出は本人。初めての App 内課金はアプリのバージョンと一緒に審査に出す）
- 有料のアプリの契約（Paid Apps Agreement）が有効か、本人が確かめる

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：開発者のサーバーへの通信なし、解析・広告 SDK なし、保存は端末の UserDefaults だけ。購入は Apple の StoreKit が扱い、開発者は購入者の情報を受け取らない。Apple Intelligence は端末の中のモデル）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）：launch・home・deck・reveal・verdict・collection・card・lab・detail・checkin・compose・catalog・paywall・settings・empty・onboarding・ダーク 3 枚。課金の審査用の画像は `docs/iap/paywall.png`。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] TestFlight のサンドボックスで Pro の購入と復元を確かめる
- [ ] 有料のアプリの契約が有効か確かめる
- [ ] 審査に提出する（App 内課金の Pro も一緒に）
