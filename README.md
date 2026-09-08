# RSS Reader

macOS 26.6以降向けのSwiftUI / SwiftData製RSSリーダー。現在は、合成記事を使って読書体験を試すオフライン開発版です。

## 起動

XcodeのSwiftツールチェーンで、プロジェクトルートから実行します。追加パッケージは不要です。

```sh
bash scripts/build-app.sh
```

生成される `.build/RSS Reader.app` をFinderから開いてください。コンパイラの中間出力は `/private/tmp/rss-reader-build` に置きます。

## 操作

- 左から購読元・記事一覧・本文の3カラム。
- 一覧にフォーカスした状態で `j` / `k` による記事移動。
- 記事を選ぶと既読。`m` で既読／未読を切り替え、`s` でLikeを切り替え。
- ツールバーからシステム追従・ライト・ダークを選択。
- 既読状態とLikeの掲載サイト・日時はSwiftDataに保存。

保存先はアプリ専用のApplication Support内 `RSSReader-Development/Reader.store` です。検証時は `--data-directory <path>` で別の保存先を指定できます。

RSS登録・ネットワーク取得・本文抽出・AI要約・b/v/Escは次の実装範囲です。現在の記事はすべて合成データで、外部通信とKeychainアクセスは行いません。

## 検証

```sh
swift test --scratch-path /private/tmp/rss-reader-build
```

2026-09-09: 4テスト成功。初期データの重複防止、ディスクストア再作成による既読・Like・本文の復元、再Like時の日時更新、選択移動の境界を検証しました。アプリバンドルのビルドも成功しています。

以前の画面確認では記事選択・Like・jによる移動を確認。今回の更新版では操作ツールがユーザー操作の競合を報告して停止したため、追加のGUI操作確認は未完了です。1万記事での応答時間、連続スクロールの滑らかさ、GUI再起動での復元は未測定・未確認です。

正式な機能要件とハーネス要件は [仕様書](docs/specification.md)、先行実装の承認範囲は [読書機能を先に作る進め方](docs/proposed-reader-first.md) を参照してください。本開発版によってF/H受入全体を合格とは扱いません。独立したTechLead/PdM検証も未実施です。
