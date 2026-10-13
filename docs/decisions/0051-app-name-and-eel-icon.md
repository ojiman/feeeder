# 0051 App name and eel icon

- Status: valid (approved by the owner in chat on 2026-10-13; implemented by PR #121).
- Date: 2026-10-13
- Decider: the owner requested “Unagi Reader” for the app icon name.
- Refines: the app bundle filename in [0023](0023-rename-to-unagi-reader.md), point 2.

The built app is `Unagi Reader.app`, so its filename matches its existing bundle display name. Local builds, CI packaging, the download script and launch instructions use that name.

The executable, bundle identifier, data directories and ZIP artifact name keep their existing names. This change does not move or delete an installed app. When installing the new build, replace the old app rather than keeping both copies.

The owner selected an orange icon with a charcoal eel in a U shape and rounded fins, without a book or text symbol. On 2026-10-13 the owner also authorized production preparation for macOS: remove the baked-in rounded corners and transparent margins while retaining the selected motif and colors. `Assets/AppIcon.png` is the 1024 × 1024 opaque, square source image and is not read by the build. `Assets/AppIcon.icns` contains its macOS sizes, made with `sips` and `iconutil`. The build copies it into the bundle and declares it in `CFBundleIconFile`.

## Display verification

The production image follows the square, unmasked, full-bleed background guidance in [Apple's app icon HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons/). It is flattened artwork; this guidance permits flattened artwork and does not require Icon Composer.

On macOS 27.0.1, Finder's Get Info preview of a freshly extracted build shows one orange icon with system-rounded corners, without the additional silver plate seen before. This is evidence for the default Finder display, not acceptance of every system appearance. Dock, macOS 26 and the Gatekeeper prompt remain unverified. See [verification](../verification/0051-app-icon.md).
