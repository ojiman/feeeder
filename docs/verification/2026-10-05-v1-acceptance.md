# Feeeder V1 実機受入記録（進行中）

V1は受入未完了。実装開始はPdM承認済みだが、読書UXの性能改善・未確認操作・最終PdM実演が残る。PASSは記載した操作だけを示し、PRD全体の受入を意味しない。

## 対象と環境

- Branch: `codex/v1-implementation`。基点`bbbc0dd7213792387f7e964212219ed95b8cdb9c`。Task 1〜5の最終commitは`eea3170228d74061e81133ee4237673043984934`。Task 6〜9の記録はその後の作業中の差分が対象。この受入記録を含むcheckpoint commitがTask 6〜9差分の固定点。最終レビューは未実施。
- Mac14,2 / RAM 16GiB / CPU 8 / display 60Hz / macOS 27.0.1 / Swift 6.4。最低対応版macOS 26.6はNOT_RUN。
- 合成RSS/HTML、予約ドメイン`.example`、一時DBだけを使用。本人の購読・記事・ノート・認証情報は使用せず、原本動画・画面画像もGitへ含めない。
- 全自動テスト67 core件 / 16 suitesに加え5 UI件 / 1 suite PASS（計72件）。release buildと`git diff --check`もPASS。SDKを使うローカルbuildと実機操作は自動テストと別に判定する。

## シナリオ別の証拠

| PRD | 観察済みの結果 | 残る確認・判定 |
|---|---|---|
| 01 読書UX | 3カラム・dark、購読整理、一覧のj/kと選択本文一致。ノート／AIレビューから復帰後にkで同じ一覧を移動できた | 切替開始p95は3回とも目標内。MainActor停止の原因判定は継続中。IME変換・VoiceOver・Reduce Motion・原文10往復の位置精度・動画とのPdM比較は未完了 |
| 02 既読 | Task 1の一覧scrollで未読6件を維持。本文表示→5、j→4、kで初回既読維持。遅延した抽出が別記事に上書きしないことを自動テストで確認 | 高速切替の最終性能試験はTask 6に残る |
| 03 取得不可 | localhost合成ページの抽出、RSS要約fallback、Coverage表示を実機確認。redirect抽出は要約を維持し、未検査転送先を取得しなかった | 実サイト抽出品質はNOT_RUN |
| 04 週ノート | 前週初期表示、現在週追加、複数ノート、日本語編集、V1 DB再openを確認。保存済み週のTimezone・DSTは自動テストで確認 | MacのTimezoneを実際に変更した実演・host networkを切った実演はNOT_RUN |
| 05 AI連携 | 単一記事／週、言語変更、除外／再追加、全文preview、TXT書き出し、起動済みClaudeへの直接起動、Attach取消→同じbytesで再試行、本人のAttach後のカードと送信前停止を確認 | 未起動からも本人によるAttach後のカードと送信前停止を確認。大きなTXTの実クライアント読取りはNOT_RUN。他版・他プラン・通常Chat自動添付はNOT_RUN |
| 06 返答採用 | 本人が確認した内容という合成文をノートへ貼付け、j/kを本文として入力、Source A/Bを明示的に採用。AIレビュー前後も本文と出典を保持 | 実AI返答の内容をアプリが保証しない。自動採用なし |
| 07 PdM受入 | 実装開始の承認済み | **最終実演・製品受入は承認待ち** |
| 08 保持・削除 | 30→7日のpreview取消と適用、6本文＋6要約の削除後も6メタデータ・2ノート維持を実機確認。期限・再受信復活禁止・管理AIコピー同期は自動テストPASS | 長時間の期限timer／復帰イベントの実時間待ちはNOT_RUN |

## AIパッケージとClaude

Claude Desktop 2.19675.0 / Pro / Coworkを検証対象とする。通常Chatは利用者の第一希望だが自動添付未検証で、この実装で対応したとは表現しない。

Feeeder本体の2出典パッケージは70,980 bytes、SHA-256 `251324463a85e7118bb60fc314211bfc1f3f4fee2dc01dd074bb9d6cacc47ffa`。日本語500行のSource Aと、全文取得不可を示すSource Bの要約・URLを含む。UTF-8厳密復号、0001〜0500の連番、両source終端とpackage終端をローカル書き出しで照合した。出典除外でSource Bのみ1,198 bytes、再追加で2出典へ戻った。English変更でも全文と終端を維持した。

日本語・空白のある生成フォルダから本体ボタンでCoworkへ遷移した。Attach取消後もTXTは消えず、同じhash・pathで再試行できた。本人がAttachを押した後、`Feeeder-review.txt`カード・Removeボタン・未送信のStart taskを観察した。FeeederはAttach完了や送信成功を推定しない。依頼文への赤い注意表示は操作を妨げなかった。

この2出典の分割書き出しは1 part / 71,199 bytes（header込み）。payloadは元の70,980 bytesとhashが完全一致。別の合成1万行を本体でレビュー・通常TXT保存・分割保存した。1,391,085 bytes、SHA-256 `e0d896535f46adc6b1db8a7c43c9514511c4807e8fe1a5e3da1fa29435cdef92`。プレビュー末尾で10000行目とEND_A / END_SOURCE / END_PACKAGEを画面確認。2 partsは1,048,510 / 342,947 bytes、両方UTF-8かつ1MiB以下で、payload連結は元の全bytes・hashと一致した。管理コピーも通常書き出しと同一。大容量でも本体からClaudeのAttach確認まで開き、送信せず取消した。分割サイズをClaudeの上限やクライアント側読取り能力とは扱わない。

本人による送信後のフォルダ読取り・変更許可、cloud処理の案内は[以前の技術probe](2026-10-04-claude-desktop-handoff.md)の実機結果に基づく。以前の70,281 bytesのSHA-256一致と今回の本体パッケージは別の証拠。本体の今回のTXTはClaudeで送信・内容照合していない。

## 読書性能の途中結果

Release / 10,000記事・100購読 / 保存済み80合成段落の記事を使用。100回のjイベントを入力しても、更新の統合により表示開始標本は100件にならない。下記p95は観察した表示更新開始標本の値で、100イベントすべての表示完了を保証しない。

| 方式・試行 | 表示開始標本 | 入力→更新開始p95 | 判定 |
|---|---:|---:|---|
| SwiftUI一覧・行Geometry | 82 | 265.57ms | FAIL |
| 行Geometry除去 | 79 | 175.02ms | FAIL。一覧復元位置も不一致 |
| NSTableView一覧 | 78 | 318.17ms | FAIL。一覧と選択の一致は改善 |
| ID索引化後 1 | 79 | 91.92ms | この区間のp95のみ目標内 |
| ID索引化後 2 | 57 | 235.49ms | FAIL。安定した合格ではない |

SwiftUI Instruments recordingの最初の1本はexportに失敗したため無効。有効なTime Profilerでは、一覧の大量ID参照を除いた後もMainThreadのlayout・本文Geometry/preference負荷が残った。MainActor heartbeatの100ms超gapも残り、gapだけをアプリ起因hangの証拠とはしない。利用者が本文scrollのAppKit適用を承認した。NSTextViewの実組版・段落復元・実表示判定をテストし、再利用と表示領域の分離で再計測中。本文を1つのNSTextViewで再利用し、短い遷移をlayer animationへ移した版（`8f91329`）で100切替×3を再計測。開始標本は64 / 69 / 62、p95は78.06 / 80.62 / 76.72ms、maxは96.12 / 89.21 / 79.89ms。選択と最終表示は99 / 199 / 299で一致し、80段落を保持した。開始標本のp95は3回とも目標内だが、統合された中間入力を100個の独立表示として扱わない。

一覧・本文の30秒連続scrollも3回実施（30.05 / 30.14 / 30.07秒、交互scroll225 / 231 / 232往復）、選択を保持した。Macロック・長いidleを含むheartbeat総数は当該操作のhang件数に使えない。35秒の有効Time ProfilerではMainThread4,082 samples中、NSAccessibility1,279 / AX位置取得1,223 / window layout161。自動操作のAX取得が負荷に含まれるため、100ms超gapをアプリ起因の停止と断定しない。MainActor停止0件の目標と最終操作感は未確定。

最初のv/Escで選択300と列幅223 / 279.5が復元した。本文の正規化scroll値は0.3310658→0.3252349の差があり、反復で累積するか確認中。ネイティブの自動幅変更10往復は、段落7＋23.5offsetを1pt未満の差で保持した。解除後、Escで本文へfocusが移り、後続キーが効かない不具合を再現した。SwiftUIのfocus flagだけでなく実際のNSTableView firstResponderを保存する修正をRED→GREENで検証。修正版の実機10往復はすべて開閉し、選択・列幅を復元、本文の正規化scroll値は初回の0.3252349から累積しなかった。1行以内の絶対差は比率だけで証明しない。

参照動画SHA-256は`e1d325cc6e6182bec03a84e1653c08b54ee2c2e80bfed04d61ffbce21267d0e1`。動画の購読切替（0〜6秒）、記事／scroll（6〜11・15〜18・30〜33秒）、原文遷移（11〜14・18〜19秒）、原文待ちと復帰（19〜30秒）に対応した最終比較は未実施。収録60fpsを描画fpsとして扱わない。

## 残る実演

Task 6の改善と測定、原文からの復元、IME・アクセシビリティ、再起動後のAI管理コピー整理を確認する。全体レビュー後にPdMが実機でPRD-01〜08を判断する。GitHub公開・署名・配布はこの検証の範囲に含めない。
