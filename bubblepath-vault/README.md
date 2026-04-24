# BubblePath Vault

This folder stores BubblePath's local disk-backed data.

- `bubblepath-data.json` is the latest saved state.
- `backups/` contains timestamped snapshots.
- regular backups are capped so the folder does not grow forever.
- pre-restore snapshots are kept separately from regular backups.
- restoring a backup creates a pre-restore snapshot of the current vault first.
- API keys are not stored in this vault.
