# Settings: ReaderView接続とキー入力の一時検証

更新日: 2026-10-10（日本時間）。**未承認の推奨案の検証記録。製品統合・性能受入ではない。**

[POの担当者向け依頼](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090875330)を対象に、ReaderView → ArticleDetailView → NSViewRepresentable → `updateReadingSize()`を一時コピーへ接続した。正式SPEC・Architecture・製品ソースは変更しない。別途開発中のAI機能を取り込まず、POの性能分解と不採用判断は維持する。

## 結論と担当範囲

接続試験3件、既存本文試験9件、POプローブ10件の計22件がReleaseで成功した。合成アプリへの実ウィンドウ入力では、⌘+／⌘−／⌘0が開いている本文を更新し、上端文字・選択・初回既読日時を保持した。15回の描画更新でinstall／load／fetch／markDisplayedの呼出し増分はすべて0。上限・下限・既定値での5回は値を変えないno-opだった。

**私の判断は、本文接続の実現性を確認できたが、即時更新の製品採用は引き続き未受入。** 約13.5万UTF-16の本文では入力から描画処理終了まで306〜383msかかった。主な時間を同期レイアウトが占め、接続してもPOの長さ依存は解消しなかった。PdMには長さ別の時間予算と、長文で許容するかキー解放時に1回適用するかの判断が必要。キー解放案は今回実装・検証していない。

## 環境・再現入力

- macOS 27.0.1 (26A434)、Xcode 27.0 (27A266a)、Apple Swift 6.4、arm64、Release。
- PO記録を確認したHEAD: `26fb8ff071f11ef6cd1554d1e11be6b1c280ebd2`。一時製品ソースは既存プローブと同じ `e9bcd933873fe920fc3751ba417afe561ff2a99c` に固定。
- 既存の初期描画／ライブ更新パッチに[接続パッチ](probes/settings-key-path.patch)、[キー橋渡し・計測](probes/settings-key-bridge.swift)、[接続試験](probes/settings-key-path.swift)を追加。製品の通常UserDefaultsとは異なるsuiteを使用。
- 合成本文3／30／200段落。35回繰返す日本語・英語・絵文字の段落。UTF-16はヘッダ込み2069／20235／134749。POの性能分解とは文章が異なるため絶対時間を直接比較しない。
- 本文領域幅727pt、スクロール領域高733pt。30段落は3ページ、200段落は20ページ下へ移動した位置から操作。選択範囲の非空保持は接続試験で確認し、UI測定では空の選択を保持。
- Bundle ID `jp.ojiman.Feeeder.SettingsProbe.7i7mlun7` の未署名ローカルコピー。PID 58600の起動引数が `--data-directory /private/tmp/feeeder-settings-keys-7i7mlun7/data-final --seed-demo` を含み、画面の合成6記事と一致することを操作前に確認した。利用者のライブラリ・既存設定に接続していない。
- 原文は[ローカルHTML](probes/settings-key-original.html)を127.0.0.1のHTTPサーバーで表示。外部記事取得・AI推論・Claude起動なし。終了後に検証アプリとサーバーを停止。

## 接続の検証

| 確認 | 結果と範囲 |
|---|---|
| Detail → nativeの接続 | PASS。先にfont20ptの表明が16ptで失敗するREDを確認後、接続を追加。同じArticleTextView・文字列・非空選択を保持。表示開始／表示完了は初回各1、再取得0 |
| ReaderView全体 | PASS。合成Storeで一度表示した記事を未読へ戻し、設定変更後も未読・初回既読日時・contentRevisionを保持。load／fetch／markDisplayedの呼出し0。font20ptへ更新 |
| キー判定の試験 | PASS。+／=／−／0、Shift、Control／Optionの拒否、4段階の上下限、編集可能NSTextView／NSTextField／marked textの拒否。marked textはテスト用responderによる論理判定で、実IMEではない |
| 実ウィンドウ入力 | PASS（限定）。CUAによるmacOSウィンドウ入力で更新し、実際のNSEvent情報を保存。ABC入力ソース。⌘+と⌘=のCUA指定はともにkeyCode24、characters `=`、ignoringModifiers `+`、Command+Shiftとなった。異なる物理キー2種類を実測した意味ではない |
| 購読追加sheet | PASS（限定）。合成文字列を入力後、3キーで本文設定が変わらず文字列も保持。キャンセルし、購読操作は実行しない。sheetが別keyWindowなので本文monitorは計測しない |
| 原文WebView | PASS（限定）。原文表示中は本文設定を変更しない。input／textarea／contenteditableのそれぞれに座標クリックでフォーカス・文字入力を確認して3キーを操作、入力を保持。42 ignored記録はイベントの再配送を含み、42物理操作ではない |
| 長押し／連打 | 一部のみ。200段落で800msの長押しを行ったがNSEvent.isARepeatはすべてfalse。短い単発入力の上下限no-opは確認できたが、実キー反復の待ち行列・解放時処理はNOT_RUN |

textareaのAXクリックではフォーカスが移らず、合成入力の`t`／`s`が既存のテーマ／Star操作に届いた。保存せずポップオーバーを閉じ、座標クリック後のフォーカスと入力を確認して再検証した。この前段の操作は本文サイズ更新の成功件数に含めない。検証データのStar状態は初期状態とは異なる。AXクリックだけを編集開始の証拠にしない。

## 入力から描画までの記録

| 本文UTF-16 | 描画更新数 | 入力→描画処理終了 ms 最小／中央値／最大 | updateReadingSize ms 最小／中央値／最大 |
|---:|---:|---:|---:|
| 2069 | 4 | 13.05／15.48／15.70 | 4.62／5.35／6.86 |
| 20235 | 2 | 68.68／70.10／71.52 | 55.39／57.82／60.25 |
| 134749 | 9 | 306.29／322.99／383.17 | 295.56／308.13／369.78 |

NSEvent.timestamp → representable更新直前 → update終了 → NSTextView.drawのsuper呼出し終了を計測。最後はCPU側の描画処理終了であり、GPU present・画面走査・人が見えるまでの時間ではない。JSON書込み・文字位置の計測など診断負荷を含む。少数の単発サンプルで、安定したSLOやp95を推定しない。性能PASS／FAILの閾値は未設定。

[結果と入力ハッシュ](probes/settings-key-results.txt)、[全キー記録](probes/settings-key-events.json)、[22試験ログ](probes/settings-key-tests.txt)を保存。描画15件すべてで上端文字保持・選択保持・初回既読日時一致・4種の呼出し増分0を機械的に照合した。これは合成接続の証拠で、将来の製品実装全体へ自動的に引き継がない。

## 再実行

```sh
bash docs/verification/probes/run-settings-key-path.sh
```

[スクリプト](probes/run-settings-key-path.sh)は固定ソースから一時コピーを作り、3パッチを適用して22試験を実行し、固有Bundle IDの未署名合成アプリとHTMLを準備する。起動・UI操作は自動実行しない。表示されたパスを `probe_source` に代入し、別ターミナルで次を起動する。

```sh
python3 -u docs/verification/probes/serve-settings-original.py "$probe_source"
```

別ターミナルで起動する。新しいdataディレクトリとsuiteを使い、既存の検証結果を上書きしない。

```sh
probe_port=$(cat "$probe_source/port.txt")
open -n "$probe_source/Feeeder Settings Probe.app" --args \
  --data-directory "$probe_source/data-ui" --seed-demo \
  --probe-suite "Feeeder.SettingsProbe.UI.$(basename "$probe_source")" \
  --probe-key-output "$probe_source/key-events.json" \
  --probe-original-url "http://127.0.0.1:$probe_port/original.html"
pgrep -fl RSSReader
```

起動引数と合成6記事を確認してから、本文3／30／200段落、+／−／0、上下限、購読sheet、原文の本文・3入力部品を操作する。終了時は検証アプリだけを⌘Qし、サーバーのターミナルをCtrl+Cで終了する。スクリプトの再生成・22試験・アプリ準備も別の一時ディレクトリで再確認した。

## 残る判断・未確認

PdMの長さ別時間予算と極端な長文の扱いが未決定。物理JIS配列／日本語IME／実キー反復、ノート編集への倍率接続・変換中保留、設定再起動保存、画像や末尾・空白位置、実記事の長さ分布、3カテゴリ完成画面、VoiceOver・Reduce Motion・長時間利用、CI環境macOS26／Swift6.3.3は未確認。製品統合の際には正式SPEC・Architecture・決定記録と、これらの受入結果を別途更新する。
