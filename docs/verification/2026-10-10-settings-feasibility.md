# Settings メニュードラフトのフィジビリティ検証

更新日: 2026-10-10（日本時間）

対象: [Settingsドラフト](../superpowers/specs/2026-10-10-settings-draft.md)。仕様を確定する前に、現行構成での実現可能性と追加検証が必要な条件を確認した。**製品コード・保存モデル・依存・正式PRD/Architectureは変更していない。** 検証専用の合成プローブを別の一時コピーで実行した。

## 結論と推奨

**基本構成は実現可能。ただし「読書位置を保つ」と「IME変換中にもノート文字サイズを即時反映する」は、そのまま仕様確定できない。**

推奨は、5カテゴリと既存の保存契約を採用候補にし、文字サイズ・行間・幅の値は仮案のままとすること。表示設定の適用方法は、次の2点を検証してから確定する。

1. 本文は同じ段落/ピクセル差への復帰では同じ文を保てない。表示中の文字位置を基準に再組版後へ戻す方式を検証する。
2. ノートはSwiftUIの`.font`変更だけではAPI生成の変換中テキストを保持できなかった。まず編集中の反映を保留し、編集終了後に反映する案を実際の日本語IMEで試す。即時反映を残す場合は、変換・選択・入力を保つ別の反映方法を検証する。

独立した設定管理基盤、SwiftDataの新モデル、依存ライブラリ、AI実装の追加は不要。既存の`Settings`・`AppStorage`・`ReaderStore`を使う方針で進められる。AIの実装と編集面への接続には、並行開発との合流が必要。

## 基準と環境

| 項目 | 値 |
|---|---|
| 基準commit | `e9bcd933873fe920fc3751ba417afe561ff2a99c`（main、問い・レンズ・答え・根拠の実装） |
| 作業ブランチ | `codex/settings-feasibility` |
| OS | macOS 27.0.1、build 26A434、Apple Silicon |
| Xcode / Swift | Xcode 27.0（27A266a）/ Swift 6.4（swiftlang-6.4.0.34.1） |
| SDK | macOS 27 SDK。macOS 26 SDK・Swift 6.3.3の検証ではない |
| 入力 | 合成した日本語/英語の文章、絵文字、架空のリンク、一時DB |
| 設定保存 | UUIDで作った専用UserDefaults suite。試験後にそのsuiteだけを削除 |
| 外部操作 | 公開GitHubのmain取得とPR作成。モデル推論・資産取得・Claude起動・記事取得なし |

当初のドラフトは`afc1cb9`を基準にしていた。調査開始時にmainを取得し、追加された問い・答えの実装を読んで、基準を上記へ更新した。open PRは開始時0件。作業コピーには本セッションの未コミットドラフトだけがあり、別AIの作業コピーは操作していない。

## 方法とスコープ

- **既存実装の確認**: `ReaderSettingsView`、`RSSReaderApp`、`NativeArticleText`、`UnderstandingEditor`、`QuestionEditor`、`ContentRetention`と、PRD/Architecture・決定0008/0009を確認。
- **既存の検証を再実行**: 基準commitに対し、本文ビュー・テーマ画面・問い編集・保持の関連試験を実行。
- **合成プローブ**: 基準commitを`git archive`で一時コピーへ展開し、[プローブのSwiftソース](probes/settings-feasibility.swift)だけをTestsへ追加。製品コードは基準commitのまま。
- **フォームの描画**: 5カテゴリの`TabView`/grouped `Form`を`NSHostingView`と試験用`NSWindow`へ載せ、カテゴリをプログラムで切り替えて内容をPNGへ描画。外観・編集・AI・保存・キー一覧の5枚を目視確認。
- **入力の確認**: 合成`TextEditor`のfont変更前後で、同じネイティブビュー・文章・選択範囲・文字サイズを比較。`setMarkedText`で作った変換中テキストは、サイズ変更しない対照と比較。
- **本文の確認**: 実際の`ArticleTextView`へ108通りのfont/行間/幅を適用し、文章・リンク・引用の字下げ・ヘッダのfontを表明。現在の位置復帰方式の限界を別途測定。
- **AI**: `SystemLanguageModel.default.availability`と日本語`NLContextualEmbedding.hasAvailableAssets`を読むだけ。モデルを呼ばず、資産の取得要求も出さない。

これは読書アプリ本体の実操作や、実際の`Settings` sceneの検証ではない。生成PNGはフォーム内容の描画で、ウィンドウのタイトルバーに置かれるカテゴリ操作は画像に含まれない。人がカテゴリを選べること・`⌘,`・最後の面の復元は未確認。

## 結果

PASSは表明した範囲だけの合格であり、製品受入ではない。

| 項目 | 結果 | 確認できたこと・限界 |
|---|---|---|
| 基準commitの関連試験 | PASS | UI 17件/3 suite、Core 6件/1 suite。合計23件。本文・テーマ・問いの既存挙動と保持の関連試験で、全テストではない |
| 合成プローブ | PASS（表明部分） | 3件、最終実行13.696秒、exit 0。下記の位置と変換中テキストは診断出力であり、成功表明には含めない |
| 5カテゴリのフォーム | PASS（描画・プログラム切替） | 640×480ptで5カテゴリの内容が描画された。フォーム内容を目視確認。実際のカテゴリ操作・Settings sceneは未確認 |
| 外観・AIの設定値保存 | PASS（部品） | 専用suiteのdark/falseを別のUserDefaultsインスタンスと`AppStorage`から読戻した。別プロセスの再起動・本体への通知は未確認 |
| 通常のノートfont変更 | PASS（部品） | 16→20→14→18→16pt。ビューの同一性・文章・選択範囲を保持し、fontが更新された。既存の保存Bindingや問いの`TextField`への接続は未確認 |
| 変換中テキストのfont変更 | FAIL（APIによる代替試験） | サイズを変えず待った対照ではmarked textが残った。20ptへ変更するとmarked rangeが`{3,4}`→`{57,0}`となり、文章も変更前と一致しなかった。実際のIMEの再現ではないが、単純な即時反映で保持できるという根拠は得られなかった |
| 本文の書式変更 | PASS（属性） | 4サイズ×3行間×3最大幅×3ペイン幅=108通り。文字列・リンク先・引用字下げ・ヘッダfontを保持。フォントを丸ごと書き直さず既存属性を残せる |
| 本文の同じ文への復帰 | FAIL（現行の位置表現の限界） | 360→1000ptの幅変更。段落7/600pxは同じだが、可視先頭のUTF-16位置は5691→6125、434 code unitの差。段落/ピクセル差の保持を、同じ文字・行の保持とは扱えない |
| 端末内AIの利用可否 | PASS（この端末） | FoundationModelsはavailable、日本語埋め込み資産は存在。非対応・資産なし・Apple Intelligence無効の端末は未確認 |
| AIオフと要求中の無効化 | NOT_RUN | 本体のAI実装は基準commitで未実装。トグル値の保存と、呼び出し抑止・遅延応答破棄は別に確認する必要がある |
| 保存・削除の既存経路 | PASS（関連Core試験） | プレビューの非破壊性、短縮、期限、保存失敗の復旧、テーマ記録の保持/再open。新Settings画面での確認/キャンセル操作は未確認 |

### 診断出力（最終実行）

```text
PROBE marked-text baseline after no-font update=true, before={3, 4}, after={57, 0}, sameText=false
PROBE marked-text preserved=false
PROBE preferences round-trip: dark, AI off; synthetic suite only
PROBE typography 108 combinations: text/link/quote/header preserved; not a production settings integration
PROBE top visible UTF16 index before=5691, after=6125
PROBE deep offset before=paragraph-7/600.0, after=paragraph-7/600.0
PROBE FoundationModels availability: available
PROBE Japanese embedding assets present: true
```

ノートのmarked text診断は、入力部品だけを使い、保存処理へ接続していない。製品で入力が消えることを証明したものではなく、提案の反映方法に追加検証が必要なことを示す。

## 実装へ届く変更と並行開発との境界

| 範囲 | 実装時に届く場所 | 合流条件 |
|---|---|---|
| 設定画面・外観・キー一覧 | `ReaderSettingsView`、`RSSReaderApp` | 先に画面の分類とラベルを決められる。動作のない仮トグルを完成品として出さない |
| 本文の文字サイズ/行間/幅 | `NativeArticleText`、`ReaderView`の呼出し、位置復帰、表示設定の保存 | 表示変更で本文を再取得/再既読化しない。通常本文と引用の両方へ届く。文字位置を保つ方式の検証が必要 |
| ノートの文字サイズ | `QuestionEditor`の問い`TextField`・答え`TextEditor`、`UnderstandingEditor` | 保存Bindingと入力状態を維持する。編集中の反映方式を実機で決める。ノート機能の変更と同じファイルに触れるため実装時には合流が必要 |
| AI | 設定値と`ThemeAssistant`呼出し側・利用可否検査 | オフ時に埋め込み/生成の両方を呼ばず、進行中の結果を破棄する契約を機能開発側と揃える。今回はAI実装を増やさない |
| 保存 | 既存`ReaderStore`/`ReaderSettings`/`DeletionPreview` | データの契約は変えない。Settingsの表示だけにして、モデルを画面から直接更新しない |

今回のPRは文書とプローブに限るので、別AIの機能実装から切り離せる。**Settingsの本実装すべてが完全に独立するわけではなく、ノート文字サイズとAI無効化の接続には合流が必要。**

## 再実行

基準commitが存在するこのリポジトリで、次を実行する。`mktemp`が毎回新しいコピーを作る。テストのUserDefaultsは専用suiteだけを使い、本人のFeeederライブラリは開かない。

```sh
probe_source=$(mktemp -d /private/tmp/feeeder-settings-probe.XXXXXX)
git archive e9bcd933873fe920fc3751ba417afe561ff2a99c | tar -x -C "$probe_source"
cp docs/verification/probes/settings-feasibility.swift "$probe_source/Tests/ReaderUITests/SettingsFeasibilityProbe.swift"
swift test --package-path "$probe_source" --scratch-path "$probe_source/.build" --force-resolved-versions --disable-keychain --disable-netrc --filter SettingsFeasibilityProbe
```

実行したコマンド:

```sh
swift test --scratch-path /private/tmp/feeeder-settings-feasibility-build --force-resolved-versions --disable-keychain --disable-netrc --filter 'NativeArticleTextTests|ContentRetentionTests|ThemeReaderTests'
swift test --package-path /private/tmp/feeeder-settings-probe-source --scratch-path /private/tmp/feeeder-settings-feasibility-build --force-resolved-versions --disable-keychain --disable-netrc --filter SettingsFeasibilityProbe
```

どちらも最終終了コード0。前者のフィルタは`ThemeReaderTests.swift`に属する`QuestionEditorTests`も含んだ（実際のログで17 UI試験を確認）。後者の108通りではテキスト属性を試験から変更しており、本体に設定の接続を実装した証拠ではない。

最初の実行はsandbox内のコンパイルキャッシュ書込みで失敗し、実行権限を付けて再実行した。プローブの最初のビルドはCGFloat/Doubleの比較型不一致で失敗し、CGFloatへ変換して再実行した。最終の結果は修正後のソースに対応する。

PNG出力は`/private/tmp/feeeder-settings-probe-0.png`〜`4.png`。一時ファイルはPRへ同梱せず、上記のプローブで再生成できる。ローカルログは`/private/tmp/feeeder-settings-baseline.log`と`/private/tmp/feeeder-settings-probe.log`。

## 未検証・今回実施しないこと

- 本体のSettings scene、`⌘,`、カテゴリの実操作と最後の面の復元、複数ウィンドウ。
- 実際の日本語IME、VoiceOver、Reduce Motion、コントラスト/透明度のシステム設定、長いノートのスクロール。
- 本文の文字位置を基準にした復帰方式、画像/引用を含む読書位置の精度、同じ行への復帰。
- 変更した文字サイズを持つ既存エディタの保存・失敗復旧、問いのTextField、実プロセスの再起動。
- AI実装との接続、非対応機器・資産なし・Apple Intelligence無効、進行中の無効化。
- 提案の文字サイズ/行間/幅のPdM比較、数千件・長時間・実データでの体験。
- macOS 26 / Swift 6.3.3のビルド・実行。本PRは`docs/**`のみなのでCIの自動実行対象外。プローブのソースもdocs配下にある。
- 製品Releaseビルド、アプリの署名・配布、正式仕様の承認、機能実装、別AIへのメッセージ送信。

既存の[問い・答えの検証記録](2026-10-10-theme-questions.md)と[テーマ画面の検証記録](2026-10-10-theme-screens.md)の未確認事項も、このプローブで解消したとは扱わない。
