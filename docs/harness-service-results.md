# 通信・OSサービスの検証 — 2026-09-06

通信の部分試験は成功。Keychain試験は、ユーザーから予期しない **`security wants to use the "login" keychain`** ダイアログが報告されたため停止した。Keychainの自動試験経路はBLOCKEDであり、本体の無人実装開始条件を満たしたとは扱わない。

## 確認できたこと

- 判定ロジックを含む単体テスト12件成功。正常系不成立・観測欠落・connection refused・通信成功・受信あり・probeクラッシュを合格扱いしない。
- loopbackとUnix socketの試験用受信サーバーを起動し、正常系では親／子の接続2件・受信2byteを各transportで確認。
- 同じ宛先へwriter、verifier、その子プロセスから接続するとEPERM、接続0件・受信0byte。共有`/private/tmp`にUnix socketを置いても、ファイルの許可だけで接続は許可されなかった。
- `com.apple.SecurityServer`と`com.apple.pasteboard.1`は正常系でlookup成功、制限付き起動ではlookup拒否。ポート取得可否のみで、既存項目やクリップボードの内容は読んでいない。

正式なKeychainサービス名はローカルの`/System/Library/LaunchDaemons/com.apple.securityd.plist`のMachServicesで確認した。最初に試した`com.apple.securityd`は正常系でもサービス不明だったため、その結果をKeychain遮断の根拠には使わない。

[通信・サービス照会の観測](evidence/harness-services.json)はCのsocket APIとexecした子プロセスの部分試験。外部／LAN／IPv6／DNS、curl／Python／ビルドscript経由、実際のLLM workerは未確認。H-B02全体はNOT_RUN。

## Keychain試験の停止と後片付け

専用パスのlegacy Keychainを作り、環境変数で渡したランダムな偽値1件を保存。検証プログラムは明示的なKeychain参照だけを使用し、CLIにも専用パスを指定した。値をログへ保存しない設計だったが、ユーザーの通常アカウント上で`login`に対するダイアログが発生した。原因を確定する前に同じ試験を続けない。

1. 初回のネイティブ試験は正常系の読取中にタイムアウト。専用Keychain削除成功。
2. 検証クライアントのアクセス許可を追加した試験はsetup中にタイムアウト。残った専用Keychainを個別に削除し、成功を確認。
3. 作成時のアクセス許可と明示アンロックを加えた試験では、プログラム上は正常系の値取得、sandbox内での取得不可、削除成功を記録した。
4. しかしユーザーから`login`ダイアログが報告された。3のプログラム上のPASSだけで無人試験に合格したとは認めない。
5. 全3回の`run/protected`にfixtureが残っていないことと、`keychain_preflight.py`／`rss-harness-fixture`に一致するプロセスがないことを確認。既存のlogin Keychainの内容を調査・削除する操作はしていない。

[最後のプログラム上の生観測](evidence/harness-keychain-raw.json)は**受入の合格証拠ではない**。手動入力の有無やダイアログとの因果関係を自動記録していなかったため、H-C02の評価はBLOCKED。ユーザーにはパスワードを入力せずキャンセルするよう案内した。OSのダイアログが消えたこと自体は未確認。

`harness/keychain_preflight.py`のCLI入口は無効化した。旧実験の本体は原因調査用に残すが、通常アカウントで再実行しない。再開には、個人のlogin Keychainと切り離した実行環境、またはダイアログを出さない検証方法について具体的な設計と確認が必要。

## 現在の範囲

ソース、アプリ用Keychain、実API、GitHub push、CIには未着手。ハーネス全体の受入は未完了。今回は通信部分の実装と、Keychain試験が通常アカウントで無人実行できると仮定してはいけないことの確認まで。
