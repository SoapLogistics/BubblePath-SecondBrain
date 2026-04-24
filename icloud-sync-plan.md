# BubblePath iCloud Sync Plan

## Goal

BubblePath should keep the same bubbles, links, and conversations available on a Mac and iPhone signed into the same iCloud account.

## Best Apple-Native Path

Use CloudKit through a native SwiftUI app.

- Store BubblePath data in the user's private iCloud database.
- Keep a local on-device cache so the app opens quickly and can work offline.
- Sync changes when iCloud is available.
- Avoid a custom server for the first version.

## Why The Browser Prototype Cannot Be The Final Sync Layer

The current prototype runs at `http://127.0.0.1:5173` and stores data in browser local storage. That is good for fast testing on this Mac, but:

- `localStorage` does not sync through iCloud.
- An iPhone cannot open the Mac's `127.0.0.1` page because that address means "this device."
- A browser app cannot silently read or write the user's iCloud Drive or private CloudKit database without additional Apple setup and user-facing sign-in flows.

The browser prototype is still useful for shaping the product feel before committing to native app code.

## Recommended Data Model

### Bubble Record

- `id`: stable UUID
- `type`: thought, question, decision, seed, file, chat
- `content`: main bubble text
- `createdAt`: creation date
- `updatedAt`: last edited date
- `x`: map position
- `y`: map position
- `archived`: boolean

### BubbleLink Record

- `id`: stable UUID
- `fromBubbleId`: source bubble UUID
- `toBubbleId`: target bubble UUID
- `createdAt`: creation date

### Message Record

- `id`: stable UUID
- `bubbleId`: parent bubble UUID
- `role`: user, assistant, note
- `text`: message body
- `createdAt`: creation date
- `model`: optional model name for AI replies

### AppSettings Record

- `guidePrompt`: how the user's GPT should behave
- `defaultModel`: preferred OpenAI model
- `updatedAt`: last settings change

Do not store the OpenAI API key in CloudKit records. On native Apple platforms, store it in Keychain.

## Sync Behavior

- Every device writes changes locally first.
- CloudKit sync runs in the background.
- If two devices edit the same bubble, prefer the newest `updatedAt` value for simple fields.
- Messages should append rather than overwrite.
- Links should be merged by stable IDs.
- Export/import should remain available as a backup escape hatch.

## Build Phases

1. Keep using the browser prototype to tune the BubblePath experience.
2. Create the native SwiftUI Mac app with local persistence.
3. Add iCloud sync using `NSPersistentCloudKitContainer` or direct CloudKit records.
4. Add the iPhone app using the same iCloud container.
5. Move API key storage to Keychain and keep GPT settings synced through iCloud.

## Decision

Use CloudKit for the real Mac/iPhone app. Keep the current browser version as a fast prototype and manual backup tool until the native app exists.
