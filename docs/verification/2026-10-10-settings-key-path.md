# Settings: ReaderView Integration and Key-Input Probe

Updated: 2026-10-10 (Japan time). **Evidence for an unapproved recommendation. This is not product integration or performance acceptance.**

This follows the [PO's hand-off](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090875330) by connecting a temporary copy from ReaderView → ArticleDetailView → NSViewRepresentable → `updateReadingSize()`. It does not change the formal SPEC, Architecture, or product source. It does not include the separately developed AI feature. The PO's performance decomposition and rejection of the viewport shortcut remain unchanged.

## Conclusion and scope

Twenty-two Release tests passed: 3 integration tests, 9 existing article-text tests, and 10 PO probes. With synthetic articles and a real app window, Command-plus/minus/zero updated the open text and retained the visible top character, selection, and first-read date. Ten drawn updates added zero calls to install, load, fetch, or mark-as-read. Three commands at a size limit or at the default value were no-ops.

**My judgment: the article-text connection is feasible, but immediate updates are not accepted for product use yet.** A synthetic article of about 135,000 UTF-16 units took 306–383 ms from the input event to completion of the CPU draw callback. Synchronous layout accounts for most of the time, so the PO's length dependency remains after wiring the caller. The PdM must set budgets by article length and decide whether very long articles update immediately or once on key release. The key-release option was not implemented or tested.

## Environment and synthetic inputs

- macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), Apple Swift 6.4, arm64, Release.
- The latest PO review was on commit `dc01fd823628bc22990a1bc5319b3ca2964d626a`. The branch includes `origin/main` through `9a9e831`; the temporary product source remains pinned to `e9bcd933873fe920fc3751ba417afe561ff2a99c` to keep the synthetic probe baseline stable and isolated from separate feature work.
- Added the [integration patch](probes/settings-key-path.patch), [key bridge and measurement](probes/settings-key-bridge.swift), and [integration tests](probes/settings-key-path.swift) to the existing initial-render/live-update patches. The probe uses a dedicated defaults suite, separate from normal app settings.
- Synthetic articles contain 3, 30, or 200 paragraphs of repeated Japanese, English, and emoji. UTF-16 lengths including the headings are 2,069 / 20,235 / 134,749. The text differs from the PO timing input, so absolute measurements are not directly comparable.
- Text viewport: 727 × 733 pt. The 30-paragraph article was scrolled down three pages and the 200-paragraph article twenty pages before operating the controls. The integration test also retained a non-empty selection; UI timing records used an empty selection.
- Launched an unsigned local copy with bundle ID `jp.ojiman.Feeeder.SettingsProbe.KRSfXc`. Before interacting, verified PID 8419's arguments included `--data-directory /private/tmp/feeeder-settings-keys.KRSfXc/data-ui --seed-demo`, and that the window showed six synthetic articles. The user's library and normal preferences were not used.
- The original page was a local [HTML fixture](probes/settings-key-original.html) served from 127.0.0.1. No external article, AI inference, or Claude hand-off was used. The probe app and server were stopped afterwards.

## Integration checks

| Check | Result and scope |
|---|---|
| Detail to native text | PASS. First observed a RED failure: font remained 16 pt when the test expected 20 pt. After wiring, the same ArticleTextView, text, and non-empty selection remained; display-start/displayed callbacks stayed at one each; reload count was zero. |
| Full ReaderView | PASS. In a synthetic Store, an article was marked unread before changing size. It remained unread with the same first-read date and content revision. Additional load/fetch/mark-as-read calls were zero, and body font became 20 pt. |
| Saved scroll position after reflow | PASS after review fix. After size change, the saved `ReaderScrollMemory` anchor/offset matches `readingPosition()`. Restoring that saved value places the same top character in the viewport. The earlier version did not refresh the saved value; the PO reproduced about 140 px of return-position drift. |
| Command predicate and responder rules | PASS. Tests `+`, `=`, `-`, `0`, Shift, rejection of Control/Option, size bounds, editable NSTextView/NSTextField allowance, and rejection while `hasMarkedText()` is true. The marked-text responder is synthetic; this is not a real IME test. |
| Actual window input | PASS, limited. CUA sent commands to the macOS app window and the probe recorded NSEvent data. The active source was ABC. CUA's `super+plus` and `super+equal` both arrived as keyCode 24, characters `=`, ignoringModifiers `+`, with Command+Shift. This does not prove behavior for two different physical keys. |
| Add-subscription sheet | PASS, limited. After typing synthetic text, the three commands left the text and article size unchanged. The sheet was cancelled; no subscription was added. A sheet is a separate key window, so the article monitor is not measured there. |
| Original-page WebView | PASS, limited. While the original page was open, article size stayed unchanged. Each of input, textarea, and contenteditable received focus by coordinate click; text entry and the three commands preserved input. The 24 `ignored` records include event re-delivery; they are not a count of physical key presses. |
| Hold and repeat | Partial. Physical key repeat and apply-on-key-release were NOT RUN in the latest run. The earlier probe held the key for 800 ms and received no `NSEvent.isARepeat` event; this is not evidence for physical repeat behavior. |

An accessibility click on the textarea did not focus it; synthetic `t`/`s` input reached existing theme/Star actions. The popover was closed without saving and the test was repeated after coordinate clicks confirmed focus and text. The preliminary attempt is excluded from the successful input checks. The synthetic library's Star state differs from its initial seed.

## Input-to-draw measurements

| Article UTF-16 units | Drawn updates | Event to CPU draw completion, min / median / max ms | `updateReadingSize()`, min / median / max ms |
|---:|---:|---:|---:|
| 2,069 | 2 | 11.54 / 16.66 / 21.79 | 5.62 / 5.66 / 5.69 |
| 20,235 | 2 | 59.93 / 67.38 / 74.82 | 47.89 / 54.29 / 60.69 |
| 134,749 | 6 | 306.05 / 317.60 / 340.42 | 294.58 / 306.77 / 323.18 |

The probe measures `NSEvent.timestamp` to just before the representable update, through the end of `NSTextView.draw`'s `super` call. The latest 47-record file contains 10 accepted/drawn updates, 3 no-ops, and 24 ignored events; the ignored events were recorded while the original WebView was active. This is CPU-side draw completion, not GPU presentation, scan-out, or time to a visible pixel. Diagnostic logging and visible-character measurement add overhead. These few single-key samples do not estimate a stable SLO or p95. There is no performance pass/fail threshold.

See [raw results and input hashes](probes/settings-key-results.txt), [all key records](probes/settings-key-events.json), and [22-test log](probes/settings-key-tests.txt). All 10 drawn records were checked mechanically for retained top character, selection, matching first-read timestamps, and zero deltas across four call counters. This is evidence for the synthetic connection, not a guarantee for a future product implementation.

## Key command approach for the product

The probe uses an `NSEvent` local monitor only to measure the input-to-update path. It compares event characters and consumes a handled event, so it does not provide visible menu commands, menu search, VoiceOver discovery, or disabled states at size limits. Do not carry this monitor into the product.

The proposed product approach is standard View-menu commands for 「文字を大きく」(Increase Text Size), 「文字を小さく」(Decrease Text Size), and 「実際のサイズ」(Actual Size), with macOS key equivalents. This lets the system resolve keyboard layouts and work through menu visibility, accessibility, responder routing, and command validation. Verify JIS and other input sources in the product before acceptance.

## Reproduction

```sh
bash docs/verification/probes/run-settings-key-path.sh
```

The [runner](probes/run-settings-key-path.sh) creates a separate copy from the fixed source, applies three patches, runs 22 tests, and prepares an unsigned synthetic app and HTML fixture. It does not launch the UI. Use the printed path as `probe_source`; start the server in another terminal:

```sh
python3 -u docs/verification/probes/serve-settings-original.py "$probe_source"
```

In another terminal, use a new data directory and defaults suite. Do not overwrite prior output.

```sh
probe_port=$(cat "$probe_source/port.txt")
open -n "$probe_source/Feeeder Settings Probe.app" --args \
  --data-directory "$probe_source/data-ui" --seed-demo \
  --probe-suite "Feeeder.SettingsProbe.UI.$(basename "$probe_source")" \
  --probe-key-output "$probe_source/key-events.json" \
  --probe-original-url "http://127.0.0.1:$probe_port/original.html"
pgrep -fl RSSReader
```

Verify the launch arguments and six synthetic articles before interaction. Operate on 3/30/200-paragraph articles with plus/minus/zero and size limits, then test the add-subscription sheet and the original-page body plus its three input controls. Quit only the probe app with Command-Q and stop the server with Control-C. The runner was also regenerated and its 22 tests and app preparation were verified in a new temporary directory.

## Remaining decisions and unverified behavior

The PdM has not set length-specific time budgets or chosen behavior for very long articles. The physical JIS layout, real Japanese IME, physical key repeat, note-editor scale connection and composition deferral, preference persistence across relaunch, image/end/gap positions, real article-length distribution, finished three-category screen, VoiceOver, Reduce Motion, long-running use, and macOS 26 / Swift 6.3.3 remain unverified. Product implementation must update the formal SPEC, Architecture, and decision record together with its acceptance evidence.
