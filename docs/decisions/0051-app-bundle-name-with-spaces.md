# 0051 App name and eel icon

- Status: approved by the owner in chat on 2026-10-13; implementation pending merge.
- Date: 2026-10-13
- Decider: the owner requested “Unagi Reader” for the app icon name.
- Refines: the app bundle filename in [0023](0023-rename-to-unagi-reader.md), point 2.

The built app is `Unagi Reader.app`, so its filename matches its existing bundle display name. Local builds, CI packaging, the download script and launch instructions use that name.

The executable, bundle identifier, data directories and ZIP artifact name keep their existing names. This change does not move or delete an installed app. When installing the new build, replace the old app rather than keeping both copies.

The owner selected the attached icon in chat on 2026-10-13: an orange rounded square with a charcoal eel in a U shape, with rounded fins. Use this exact version without a book or text symbol. `Assets/AppIcon.png` preserves the selected image; `Assets/AppIcon.icns` contains the macOS icon sizes. The build copies the icon into the bundle and declares it in `CFBundleIconFile`.
