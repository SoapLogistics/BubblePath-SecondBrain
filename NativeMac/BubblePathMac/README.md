# BubblePathMac

This is the first native Mac app scaffold for BubblePath.

The current goal is not to replace the browser prototype yet. The goal is to create a stable native direction:

- SwiftUI interface
- Local JSON vault loading and saving
- Keychain shape for the OpenAI API key
- OpenAI Responses API client shape
- Data models that match the browser prototype vault format

The browser prototype remains the fastest place to tune the feel. This native scaffold is where durable Mac and iCloud work can grow.

## Prototype Vault Compatibility

The native scaffold expects the same JSON shape saved by:

`bubblepath-vault/bubblepath-data.json`

That keeps migration simple while the app is young.

## Build

After installing Xcode Command Line Tools, run:

```bash
swift build
```

from this folder.

The scaffold currently builds with Apple Swift 6.1.2.

## Local App Bundle

From the project root, run:

```bash
./scripts/package-native-mac.sh
```

That creates:

`dist/BubblePath.app`

The user-facing launch notes are in `MAC_QUICK_START.md`.
