# BubblePath Native Mac App Roadmap

## Direction

Build the real BubblePath app as a native SwiftUI Mac app first, then reuse the model and sync layer for iPhone.

The browser prototype should keep proving the feel. The native app should own durable storage, iCloud sync, Keychain, and the long-term user experience.

## Foundation

- SwiftUI for the Mac interface.
- SwiftData or Core Data for local persistence.
- `NSPersistentCloudKitContainer` if using Core Data with CloudKit sync.
- Keychain for the OpenAI API key.
- Private iCloud database for bubbles, links, messages, and GPT style settings.

## Local Data First

Every device should have a local copy of the user's BubblePath data.

- App opens even when offline.
- New bubbles save immediately on-device.
- AI conversations append to local storage first.
- iCloud sync follows when available.

## Suggested App Modules

- `BubblePathApp`: SwiftUI app entry.
- `BubbleStore`: loads, saves, and syncs bubbles.
- `BubbleMapView`: visual bubble path canvas.
- `BubbleDetailView`: selected bubble editor and conversation.
- `AIClient`: talks to the OpenAI Responses API.
- `KeychainStore`: saves and reads the API key.
- `CloudSyncStatus`: shows whether iCloud is available and current.

## Migration From Prototype

1. Keep the current browser prototype as the sketchpad.
2. Use `bubblepath-vault/bubblepath-data.json` as the migration format.
3. Build a native importer that reads the JSON vault.
4. Recreate the same core interactions in SwiftUI.
5. Add CloudKit sync after local save/load is solid.

## First Native Milestone

The first native Mac version should support:

- Create, edit, delete bubbles.
- Drag bubbles on a canvas.
- Link bubbles together.
- Add local notes and GPT replies.
- Save all data locally on disk.
- Export and import the same JSON vault format.
- Store the API key in Keychain.

## Second Native Milestone

Add iCloud:

- Sync bubbles across Mac and iPhone.
- Merge appended messages safely.
- Keep local editing responsive while sync runs.
- Show simple sync status.

## Backup Principle

BubblePath should always have at least two durable paths:

- The normal app database.
- A readable JSON export/import vault.

No important thought should exist only in a browser cache, a chat thread, or a remote model session.
