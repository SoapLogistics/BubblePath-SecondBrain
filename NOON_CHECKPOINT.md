# BubblePath Noon Checkpoint

Date: 2026-04-21

## What Changed Overnight

- Strengthened the browser/local-vault path:
  - restore flow
  - backup list
  - backup policy visibility
  - retention caps for regular backups and pre-restore snapshots
  - clearer labels for backup types
- Kept the local vault/server healthy and documented the on-disk behavior in `bubblepath-vault/README.md`.
- Turned the native Mac scaffold into a real compiled path:
  - `swift build` now succeeds
  - draggable bubble map
  - connection editing
  - local JSON vault load/save
  - import/export
  - Keychain-backed API key storage
  - Ask GPT flow with recent message history
  - pending/thinking state
  - timestamps/model labels in messages
  - visible vault target
  - visible backup counts/retention caps
  - visible last-saved time
  - explicit switch back to shared project vault
  - truthful sync-readiness panel

## What Was Verified

- Browser preview server responds at `http://127.0.0.1:5173`
- Vault API health endpoint responds
- Vault API backups endpoint responds
- `app.js` syntax passes
- `server.js` syntax passes
- Native Mac scaffold builds with `swift build`

## What Still Remains

1. Add CloudKit/iCloud sync to the native app.
2. Decide long-term vault ownership between browser prototype and native app.
3. Optionally add age-based backup pruning in addition to count limits.
4. Improve native GPT UX further, such as streaming.
5. Add more native run/polish beyond compile success.

## Best Return Files

- `HANDOFF_NOTES.md`
- `PROJECT_STATUS.md`
- `NATIVE_MAC_APP.md`
- `bubblepath-vault/README.md`
