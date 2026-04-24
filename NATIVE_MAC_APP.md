# BubblePath Native Mac App

The native Mac scaffold lives here:

`/Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any/NativeMac/BubblePathMac`

Use this file as the clickable entry point if the folder link does not open in Codex.

## Current Status

- SwiftUI app scaffold exists.
- It builds with `swift build`.
- It now packages into a local app bundle at `dist/BubblePath.app`.
- It can be launched from `Launch BubblePath.command` or `run-native-mac.sh`.
- It can be kept in the Dock after opening `dist/BubblePath.app`.
- It has a custom BubblePath app icon in the packaged bundle.
- The packager keeps reusing `dist/BubblePath.app`, so a kept Dock icon opens the newest packaged build after repackaging.
- It debounces autosave while editing and flushes pending edits when the app leaves the foreground.
- It reads and writes the same local vault JSON used by the browser prototype.
- It has a basic three-column layout:
  - capture/list
  - bubble map
  - selected bubble detail/conversation
- The native map can drag bubbles and draw links.
- The selected bubble detail can create and remove connections.
- API key storage works through the Keychain helper code.
- GPT model and guide prompt are saved locally on the Mac.
- The selected bubble detail can send an Ask GPT request through the OpenAI Responses API client.
- The native app shows whether it is using the shared project vault or a custom imported vault.
- The native app can switch back to the shared project vault after testing another JSON file.
- The native app shows backup counts, retention caps, and a last-saved time.
- The native app includes a truthful sync status panel that says local-first now and CloudKit next.

## Backup Safety

- The browser/vault server side now caps retained regular backups and pre-restore backups separately.
- The native app still shares the same JSON vault shape, so those protections matter to both tracks during early development.
- The native app can import and export BubblePath JSON backups.
- Ask GPT requests now include recent user/assistant conversation history for the selected bubble.

## Build Command

```bash
cd /Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any/NativeMac/BubblePathMac
swift build
```

## Serviceable Launch Path

From the project root:

```bash
./scripts/package-native-mac.sh
open dist/BubblePath.app
```

Or double-click:

`Launch BubblePath.command`

See `MAC_QUICK_START.md` for the shortest user-facing instructions.

## Important Files

- `NativeMac/BubblePathMac/Package.swift`
- `NativeMac/BubblePathMac/Sources/BubblePathApp.swift`
- `NativeMac/BubblePathMac/Sources/ContentView.swift`
- `NativeMac/BubblePathMac/Sources/BubbleMapView.swift`
- `NativeMac/BubblePathMac/Sources/BubbleStore.swift`
- `NativeMac/BubblePathMac/Sources/Models.swift`
- `NativeMac/BubblePathMac/Sources/KeychainStore.swift`
- `NativeMac/BubblePathMac/Sources/OpenAIClient.swift`
