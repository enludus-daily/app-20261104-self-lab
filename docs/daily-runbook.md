# 毎日の手順（22:00 JST に新しいセッションで実行）

目標：**課題を1つ見つけ、使ってもらえる iOS アプリを作り、TestFlight に上げて内部テストに配信し、App Store Connect の情報を API で入れて提出の直前まで整える。** 提出・App プライバシーの申告・年齢区分は本人が行う。
迷ったら `.claude/skills/dev-judgment`、考える段階は `.claude/skills/dev-lifecycle`、実装の始めと終わりは `.claude/skills/dev-workflow`。この手順と `CLAUDE.md` の読み替えが優先。

## 0. 準備（10 分以内）

1. `enludus-daily/daily-ideas` は予約実行の設定で最初から付いている（無ければ `add_repo` で push 付きで付ける）。clone して使う。テンプレートは付けずに `git clone --depth 1 https://github.com/enludus-daily/daily-app-template` で読む（public）。
   **Vault・個人のリポジトリ・daily-actions は付けない。** daily-actions（CI・ガード・検査）を直すのは、本人が始める整備用のセッションか、本人がそのセッションで明示的に許したときだけ。
2. `TZ=Asia/Tokyo date +%F` を今日の日付にする。daily-ideas に今日の Issue（ラベル `daily`）がすでにあれば、そこから続ける（二重に作らない）。
3. daily-ideas に今日の Issue を作る：タイトル `YYYY-MM-DD: （作るものが決まったら書き換え）`、ラベル `daily`、`building`。

## 1〜4. 課題を探して、作るものを決める（30 分以内）

dev-lifecycle の 1〜4 を **短く**（各数行）行い、今日の Issue に書く。
- 材料は、daily-ideas の open の `idea` Issue（本人や他の人が書いたもの。古い順に優先）。無ければ Web で探す（困りごとの声、既存アプリのレビューの不満など）。出典の URL を書く。
- 条件：**1 日で作れる**、端末の中だけで完結、ログイン・サーバー・課金なし、個人データを集めない、既存の有名アプリ・ゲームの再現ではない。
- **本人が向けてほしい方向（2026-11-03）**：
  - 流行りのアプリ・ゲームの真似ではなく、**組み合わせ**（例：二つのジャンルや習慣を合わせる）か、**まだ解かれていない課題の解決**を狙う。
  - **iPhone Duo（折りたためる iPhone）を活かすもの、または Duo を使う人の不満を解くもの**（例：レビューや SNS の不満の声から探す）。Duo の内側の大きな画面・外側の画面・開け閉め・Split View で使いやすいこと。並べ方は size class で変える（機種・向き・`UIScreen.main` で決めない）。CI は Xcode 27.1 の iPhone Duo のシミュレータでテストする。Apple の一次資料（Tech Talk「Prepare your app for iPhone Duo」「Design for iPhone Duo」）で確かめ、出典を書く。Duo 以外の iPhone でも普通に使えること。
  - **Apple Intelligence（端末上のモデル）を使うもの**。使い方・対応機種・言語・使えるかの確かめ方は、その日に Apple の一次資料（developer.apple.com の Foundation Models など）で確かめ、出典を書く。使えない端末・設定・言語では、代わりの動き（モデルなしで使える形、または説明の表示）を必ず作る。モデルを呼ぶ所はプロトコルで差し替えられる形にし、テストは差し替えた偽物で書く（CI のシミュレータで本物のモデルが動く前提にしない）。デプロイの最低 iOS を上げる場合は理由を書く。
- **使ってもらえる水準（本人の評価 2026-11-04：「この程度か」「淡白」を繰り返さない）**：
  - 入力欄と結果を表示するだけの道具にしない。**毎日開く理由**（復習・積み上げ・続けた日数など、使うほど価値が増える仕組み）を入れる。
  - 最初に開いた 10 秒で価値が分かる（見本のデータ、空の画面にしない）。
  - 主な流れが 2〜3 画面で気持ちよく回る。見た目も仕上げる（色・アイコン・カード・動き。SF Symbols を使う）。
  - 本人の希望の例：日本語を入れると英語が出て、そのまま勉強のワークになる（作って TestFlight に上げた：app-20261103-spread-diary「言いたい英語ドリル」）。同じ枠組みの焼き直しはしない。
- **審査とアカウントを守る条件**（App Store Review Guidelines 4.2・4.3）：
  - 4.3(b) に挙がる種類（懐中電灯・効果音・壁紙・単純なタイマー・占い・出会いなど）は選ばない。同じ枠組みの焼き直し（前に作ったアプリと名前や見た目だけ違うもの）も作らない。繰り返すと開発者のアカウントから外されることがある。
  - 既存のアプリとの**意味のある違い**と、**長く使える価値**を、それぞれ1行で書く。書けなければ別の課題にする。
- 書くこと：だれの・どんな場面の困りごとか／証拠と強さ／最小の形（画面 1〜3 枚）／作らないもの／既存との違い／長く使える価値／**収益の道筋**（なし・投げ銭・買い切り・広告の候補。毎日のアプリには入れず、本人があとで選ぶ材料にする）／見直す条件。
- 使った `idea` Issue には、今日の Issue へのリンクをコメントし、ラベル `used` を付ける。

## 5. 枠（Bundle ID）を確保する

`daily-ideas/slots.json` で、`status: "free"` の最初の枠を `building` にし、`repo` と `date` を書いて daily-ideas の main に push する。
**空きがなければ**：TestFlight はせず、CI でのビルドとテストまでにする。今日の Issue に `needs-human`（「枠を足してほしい」）を付ける。

## 6. リポジトリを作る

名前：`app-YYYYMMDD-<英小文字とハイフンの短い名前>`（例 `app-20261104-water-log`）。public。
1. **作成は daily-ideas の Actions に頼む**（セッションは組織向けの API を呼べない。トークンも持たない）：
   `gh api -X POST repos/enludus-daily/daily-ideas/actions/workflows/create-app-repo.yml/dispatches -f ref=main -f 'inputs[name]=<名前>' -f 'inputs[description]=<一文>'`
   - `gh api repos/enludus-daily/daily-ideas/actions/workflows/create-app-repo.yml/runs?per_page=1` で、その実行が `success` になるまで待つ（数十秒）。
   - 失敗したら、ログの要点を今日の Issue に書いて `needs-human` にする（名前を変えて何度も試さない。作成は1日2回まで）。
   - `repos/.../generate` などで自分で作ろうとしない。
2. `add_repo`（push）で付けて clone し、`scripts/new-app.sh --name <型名> --display <表示名> --slot <枠>` を実行する。
3. コミットの作者を本人にする（最初のコミットの作者＝トークンの持ち主＝本人）：
   `git config user.name "$(git log --reverse --format=%an | head -1)" && git config user.email "$(git log --reverse --format=%ae | head -1)"`

## 7〜9. 形を作る → 実装 → テスト

- 画面は SwiftUI。処理は画面から切り離し（`Tally.swift` の例）、`Tests/` に振る舞いのテストを書く。
- アイコン：`python3 scripts/make-icon.py --bg ... --fg ... --glyph ...`（1024×1024、透過なし）。
- UserDefaults 以外の required reason API を使ったら、`App/Resources/PrivacyInfo.xcprivacy` を更新する。
- README.md を、その日のアプリの説明に書き換える（何を・だれの・どう使うか・作らなかったもの）。
- push（pre-push で検査と上限）→ CI を待つ → 失敗はログを読んで直す。**同じ失敗が 2 回で止める。**

## 9.5 見直しのループ（ゴールを下げない。最低 2 周）

ゴールは「**本人が毎日使いたくなる**」。動いた・CI が通った、で終わりにしない。
1. 主な画面をすべて撮る：アプリは起動引数 `-screenshotScene <名前>` で各画面を開けるようにし（UserDefaults の `screenshotScene` を読む）、`.github/workflows/ci.yml` の `screenshot-scenes` に並べる（例：`launch drill detail compose launch@dark`）。CI の artifact `screenshots` を開いて自分の目で見る。
2. 厳しく見て、弱い所を 5 つ以上書き出す：見た目（個性・余白・色・文字の大きさ・ダークモード）、最初の 10 秒、毎日開く理由、手応え（動き・振動・音）、飽きないか、Duo の内側の画面。
3. 大きい順に直し、テストを足し、CI → 撮り直し → 2 に戻る。
4. 「自分が利用者なら明日も開くか」に、理由を付けて「はい」と言えるまで回す。言えないまま止めるときは、何が足りないかを報告に書く。
周ごとに、書き出した弱い所と直したことを今日の Issue に短く残す。

## 意見への対応（本人の意見が来たら、そのたびに TestFlight まで）

- 本人の意見は、daily-ideas の Issue（ラベル `feedback`、本文にアプリのリポジトリ名）か、そのアプリのリポジトリの Issue に来る。毎日のセッションは、**新しいアプリを作る前に**、open の `feedback` を古い順に対応する（そのアプリのリポジトリを `add_repo` で付けてよい）。
- 対応：意見の奥の課題を考える（言われた形だけをなぞらない）→ 直す → 9.5 の見直し → CI → TestFlight（`distribute` で本人に届く）→ 必要なら `asc.yml` で情報を直す → Issue に「何を直したか・ビルド番号・CI と TestFlight の run の URL」を書いて閉じる。
- 上限（TestFlight 10 回/日）は、意見ごとに出せるように引き上げてある。

## 10〜11. TestFlight

1. CI が main で通ったら：`gh api -X POST repos/enludus-daily/<repo>/actions/workflows/testflight.yml/dispatches -f ref=main`
2. 実行を待ち、結果を確かめる。署名・権限のエラーなら直そうとせず止める（daily-actions の `docs/signing.md`）。
   - 実行の中の `distribute` ジョブが、ビルドの処理を待って（最大 45 分）内部テストのグループ `daily-internal`（無ければ作る。全ビルドを自動で配信）に入れる。これで本人の TestFlight に届く。
   - `distribute` だけが失敗したら、アップロードはやり直さず `asc.yml` を `inputs[command]=distribute` で実行する。
3. 成功したら `slots.json` の枠を `testflight` にする。

## 12. 提出の直前まで

1. `docs/app-store.json` を埋める：アプリ名（**AI が決める**。本人の許可 2026-11-04。30 文字以内）、サブタイトル、カテゴリ、キーワード、宣伝文、説明、テストの内容。`PRIVACY.md` をそのアプリに合わせる。
2. `docs/app-store.md` を埋める：審査の危険、収益の道筋、App プライバシーの答えの下書き（「データの収集なし」の根拠）、年齢区分の答え。
3. push して CI が通ったら：`gh api -X POST repos/enludus-daily/<repo>/actions/workflows/asc.yml/dispatches -f ref=main -f 'inputs[command]=metadata'`
   - 名前・サブタイトル・プライバシーポリシー URL・カテゴリ・説明・キーワード・サポート URL・宣伝文を入れ、提出用のバージョンに最新のビルドを選ぶ（提出はしない）。
   - 権限・署名のエラーなら直そうとせず止める。名前が使われていて入らないときは、別の名前にして 1 回だけやり直す。

## 終わりの報告（今日の Issue にコメント）

```
状態: ready-for-review | needs-human（理由）
アプリ: <repo の URL> / Bundle ID com.enludus.daily.<枠>
CI: <run の URL> 成功/失敗
TestFlight: ビルド <番号> をアップロードした（処理状況は未確認）/ 未実施（理由）
TestFlight の配信: 内部テストのグループ daily-internal（成功/失敗、run の URL）
App Store Connect の情報: 入れた/未実施（asc の run の URL）
本人がすること: App プライバシーの申告、年齢区分、TestFlight での確認、スクリーンショットの確認、審査への提出
判断: <AI が決めたこと> — <理由>
未実施: <何を>（<理由>）
回数: push <n>/40、CI <n>/40、TestFlight <n>/10、App Store Connect <n>/20
Vault: 対象外（daily のセッションには付けない）
```
ラベルを `ready-for-review` か `needs-human` にし、`building` を外す。
