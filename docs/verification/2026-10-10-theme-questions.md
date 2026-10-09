# 問い・レンズ・答え・根拠（PR 5）の検証

更新日: 2026-10-10（日本時間）

対象: [PR 5の計画](../superpowers/plans/2026-10-10-theme-questions.md)。環境はMac14,2 / macOS 27.0.1 / Swift 6.4（ローカル）。入力は合成データだけで、本人のライブラリは使っていない。

## 自動検証

| 項目 | 結果 |
|---|---|
| 全テスト | PASS（レビュー修正後に再実行。Swift Testing、ReaderCore・ReaderUIの全件） |
| Releaseビルド・署名検証・`git diff --check` | PASS |
| 保存失敗・再読み込み失敗の注入 | 問いの追加（文あり・レンズ）・更新・答え・根拠・削除を`failedSaveLeavesNoPartialThemeStateAndCanBeRetried`と`eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds`へ追加（レンズ版はレビュー指摘で追加） |
| 存在しない問いの選択のフォールバック | 純粋関数`ThemeQuestionSelection.resolved`の決定的な試験（取り除くと失敗することを確認）。UI試験`aMissingQuestionSelectionFallsBackToTheUnderstanding`は補助の煙試験で、単独の証拠にしない |

## 合成インスタンスでの実操作（別Bundle IDのコピー、一時データ`--seed-demo`）

確認できたこと:

- テーマの「問い」面に、先頭の「いまの理解」と問いの一覧が出る。
- レンズから問いを立てると、テーマ名を差し込んだ下書きの問いが作られ、その問いが選ばれて右に編集面が出る。
- 答えを書くと、一覧の行に回答済みの印が付く。根拠のチェックが付く。
- 「読む」を押すと「記事」面へ移り、その記事が選ばれて読書面に出る。

## 未検証（PASSにしない）

- 記事面から「問い」へ戻したときに、同じ問いが選ばれたままか（背景操作ではセグメントの切り替えが届かなかった）。選択の保持は`ReaderWorkspaceState`の純粋な試験で確認済み。UI試験は初期の選択を与えるだけで、面を往復する操作は試験していない。
- 自由に書く問いのダイアログ、問いの文を空にして確定したときの差し戻し、右クリックでの削除と確認（操作ツールがキー入力・右クリックメニューを届けられない）。ロジックはストアの試験で確認済み。
- ポップオーバーを閉じた直後に「自由に書く」のアラートが出るか（同じ更新で閉じて開くため、macOSで落ちる可能性）。
- 日本語IME変換中の入力、VoiceOver、複数ウィンドウ、長い答えのスクロール。
- macOS 26のCIの結果（このPRのCIで確認する）。

## 独立レビュー（opus、固定commit `de69590`）と対応

Critical 0・Important 3。

| 指摘 | 対応 |
|---|---|
| 問い文の編集が、フォーカスを持ったまま「読む」・[記事]・「問いを立てる」で編集面が消えると、確定されずに失われる | `QuestionEditor`に`onDisappear`で確定を追加。UI試験`aQuestionTextEditIsSavedWhenTheEditorIsRemovedWhileStillFocused`を先に書き、修正前に失敗・修正後に成功を確認 |
| レンズ版`addQuestion`が失敗注入の一覧に無かったのに、記録は「追加済み」と書いていた | 両方の一覧へ追加し、記録を正した。再読み込み失敗と重なった改名の名前が下書きへ漏れないことも表明に加えた。ただしこのローカル環境（macOS 27）では先頭の`reloadIfNeeded()`を外しても失敗しない（漏れはmacOS 26固有の挙動）。macOS 26のCIでの確認に委ねる |
| 検証記録が存在しない証拠（UI試験での選択保持）を主張していた | 上の表を実態に合わせて訂正 |

Minorへの対応: 何も確認できない否定の表明（`questionFaceShowsTheSelectedQuestionsAnswer`）を、いまの理解の本文が出ないことの確認に変更。READMEの自動削除しない一覧に問い・答え・根拠を追加。見送り: 自由に書く問いの保存失敗時に入力を残す、ポップオーバーからアラートへの遷移の実機確認（未検証に追記）、保存後の再読み込み失敗が保存失敗と表示される既存の挙動。
