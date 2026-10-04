# ハーネス初回検証 — 2026-09-06

> これは当時の部分試験の記録であり、現行V1のハーネス合格証拠ではない。現行の条件は [Architecture](architecture.md) を参照する。

## 追加指示後の現状

ユーザー判断により`/private/tmp`を共有の破棄可能領域として許可。ソース・保護対象・証拠はプロジェクト内に置く構成へ変更した。一時領域を理由とするBLOCKEDは解消した。GitHub pushとCIは、アプリが動くまで後回しにし、ローカルcommitで進める。

- 設定生成テスト: 5件成功。共有一時領域へ保護対象を置く設定の拒否も確認。
- ネイティブ試験: control・writer・verifierの各ロールで、親／子それぞれの12観測が期待値と一致。一時ファイルの読書・削除は成功。共有一時領域外の保護対象の直接／相対／symlink読取と書込は拒否。verifierのSource書込拒否、専用出力の操作成功。
- [変更後の観測・実行設定ハッシュ](evidence/harness-shared-temp.json)。全H受入や実際のLLM workerの隔離を証明したものではなく、残りの§4.5確認は未実施。
- 試験した設定: [writer](evidence/harness-shared-temp-writer.toml) / [verifier](evidence/harness-shared-temp-verifier.toml)。試験用の実体パスを含む記録であり、本人のCodex設定へ導入したものではない。

以下は初回の履歴。旧要件に対するFAILは書き換えず、ユーザーが変更した要件に対する再試験と分けて残す。

## 初回の状態（更新前）

**当時のCodexプロファイル案は採用不可。アプリの無人実装開始はBLOCKEDだった。**

仕様承認後、ローカルGit、AGENTS.md、実装順序、外部依存なしの設定生成とCの否定試験を用意した。本人の設定・認証・データは変更していない。GitHub connectorの認証ユーザーは`ojiman`。`ojiman/rss-reader`の取得は404で、未作成と権限不足は区別できない。remote作成・pushは行っていない。

## 実測

| 試験 | 結果 | 意味 |
|---|---|---|
| 設定生成の単体テスト | 4件成功 | 環境変数allowlist、role別設定、未知roleの拒否。OS境界の証明ではない |
| 現在のdesktop sandbox内から起動 | BLOCKED | `sandbox-exec: sandbox_apply: Operation not permitted`。子プロセスの試験は始まらなかった |
| 許可を得たネイティブ起動、canaryを`/private/tmp`へ配置 | FAIL | protectedの直接／相対／symlink読取と書込が成功。検証者によるSource書込も成功。子プロセスでも再現 |
| 同じ試験のcanaryをプロジェクト内へ配置 | 部分試験成功 | 正常系成功、保護対象はEPERMで拒否、検証者のSource書込拒否、出力書込・削除成功。親と子で一致 |
| `:root`、`:slash_tmp`に加えて`/private/tmp`も明示deny | FAIL | 一時領域に置いた対象への不正な読書が再現 |

Codex 0.149.1、Xcode 26.6 (17F113)。OSと個々のコマンド、設定・probeハッシュ、期待値・観測値は添付JSONに記録。部分試験のPASSをH全体のPASSへ転記しない。

保管した証拠:

- [プロジェクト内配置の観測](evidence/harness-workspace.json)
- [実体パスのdenyを含む一時領域配置の観測](evidence/harness-temp-deny.json)
- [最終のwriter設定](evidence/harness-writer.toml)
- [最終のverifier設定](evidence/harness-verifier.toml)

`:minimal`を使うネイティブ実行の一時領域の扱いが関与していると考えられるが、Codex内部の原因までは確定していない。`-P`へ存在しない名前を渡すとundefined profileとして拒否されることは別途確認した。個人の秘密ファイルを読む試験は行っていない。

## 受入状態

- H-B01/03: 部分シナリオにFAILがある。現構成での受入は不可。
- H-C01: 親・子への偽TOKEN非継承を部分確認。可読ファイル・全runtime経路を含む受入はNOT_RUN。
- その他H、TechLead/PdMの実装snapshotレビュー: NOT_RUN。現在の広いspawn権限を読取専用の独立workerと偽って使わない。
- F-01〜10: NOT_RUN。アプリのコードはまだ作成していない。

## 次に必要なこと

1. この最小再現を基に、Codexの実効sandboxで一時領域を拒否できる構成／修正版を確認する。文書上のdenyだけでは採用しない。
2. 分離が成立しない場合は仕様§4.2に従い、専用macOS実行環境への変更をユーザーと判断する。専用アカウントだけで全H条件が自動的に合格するとは扱わない。
3. 否定試験の不足部分を通し、ユーザーがポリシー・基準版を採用してから、3カラムと購読管理の実装へ進む。

再現コマンドは[harness README](../harness/README.md)。初回試験のための一時設定は本人の`~/.codex/config.toml`に導入していない。

参考: [公式permission profiles](https://learn.chatgpt.com/docs/permissions)。このページの設定例とCLIのhelpを用いたが、受入判断は上記実測に基づく。
