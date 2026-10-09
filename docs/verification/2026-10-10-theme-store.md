# テーマの保存基盤（PR 3）の検証

更新日: 2026-10-10（日本時間）

対象: [実装計画](../superpowers/plans/2026-10-10-theme-notes.md)の第2部（PR 3）。`Theme`・`ThemeArticle`・`ThemeQuestion`、`QuestionLens`、`ReaderStore`のテーマ操作と索引を追加した。**保存層のみで、画面・キー・旧モデルの削除・AI・Claude連携は含まない。** ベースは`main` `83da6af`。環境はMac14,2（Apple Silicon）/ macOS 27.0.1 / Swift 6.4（ローカル）。本人のライブラリ・購読・認証情報は使っていない。入力は合成デモと合成fixtureだけ。

## 自動検証

| 項目 | 結果 | 内容 |
|---|---|---|
| 全テスト | PASS | ReaderCore 127件＋ReaderUI 25件（既存109＋新規18、ReaderUIは変更なし）。`swift test --scratch-path /private/tmp/feeeder-dogfooding-build` |
| `ThemeTests` | PASS | 18件。作成・名前・理解・削除、記事の追加（要約の記録、再追加で上書きしない、期限切れ・要約なしは空）、購読解除・本文期限後の保持、Starとの独立、未整理のStar、複数テーマ、問い・答え・根拠、テーマ削除の範囲、保存失敗の注入、再open、失敗後の回復 |
| 回復試験 | PASS | 既存の`failedRecoveryBlocksChangesUntilReloadSucceeds`に、新しい11の変更経路を追加 |
| 配布済みbeta.2のストア | PASS | `scripts/prepare-v1-store-fixture.sh`で基準commit `f9db83b49a82947a7031ddf874bc94fcb91ef89d`の合成ストアを作り、`FEEEDER_V1_FIXTURE_DIR`を指定した`V1StoreUpgradeTests`が成功。モデルを3つ追加した新スキーマで2回open。購読・記事・既読・期限・本文・週ノート・出典・Star・日次ノート・スクラップを保持。指定なしではスキップされることも確認 |
| Releaseビルド | PASS | `bash scripts/build-app.sh release`、`codesign --verify --deep --strict` |
| `git diff --check` | PASS | |

## 試験が失敗を検出できることの確認

新しい試験の一部は、実装が先にあるため最初から通る。そこで、実装を1か所ずつ壊して、試験が失敗することを確認し、すぐに元へ戻した。

| 壊した実装 | 失敗した試験 |
|---|---|
| `saveAnswer`が保存エラーを握りつぶす（`try?`） | `failedSaveLeavesNoPartialThemeStateAndCanBeRetried` |
| `setEvidence`が根拠を保存しない | `failedSaveLeaves…`、`everythingSurvivesAReopen` |
| `renameTheme`から先頭の`reloadIfNeeded()`を外す | `eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds`（**既存の回復試験は通ってしまった**） |

3つ目の発見が重要だった。既存の`failedRecoveryBlocksChangesUntilReloadSucceeds`は、`save()`が再読み込みの完了前に保存を拒否するため、`reloadIfNeeded()`の有無を区別できない。そこで、再読み込みが可能になった後の**最初の呼び出し**で各変更経路が成功することを確認する試験を追加した（計画には無い追加。ledgerの判断に記録）。

## 未検証（PASSにしない）

- 画面・キー操作・IME・VoiceOver（この変更は保存層のみで、UIに接続していない）。
- 本人の実データでの動作、数千件規模での索引の再構築コスト（`reload()`は変更のたびにテーマ関連も取得し直す。合成デモの数件でのみ確認）。
- SwiftDataの`[UUID]`属性（`evidenceArticleIDs`）は、再open試験（`everythingSurvivesAReopen`、`evidenceMustBeThemeMembers…`）で永続化を確認したが、モデル変更をまたぐ移行（1.0以降）は未検証。
- 旧モデル5つを外した新スキーマで現行ベータのストアを開けるか（PR 4の最初のTaskで確認する）。
- macOS 26のCIでの結果（このPRのCIで確認する）。ローカル成功は必要条件であり十分条件ではない。
- 最低版以外のOS・機種、長時間利用。
