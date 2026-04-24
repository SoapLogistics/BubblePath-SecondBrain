# BubblePath Server Quick Start

Last updated: 2026-04-24

## What The Server Is For

Use the Ubuntu box as BubblePath's always-on helper:

- network storage
- incoming drop zone
- background cleanup and processing
- future import/index/search services

Keep the native Mac app as the main place where BubblePath is used and tested.

## Connection Details

- Tailscale hostname: `dell-bubblepath`
- Tailscale IPv4: `100.120.102.102`
- SSH user: `millerm`
- Finder share: `smb://192.168.4.78/Shared`

## Termius Setup

Create a manual host entry with:

- Label: `BubblePath Server`
- Address: `100.120.102.102`
- Username: `millerm`
- Port: `22`
- Auth: password

If the direct Tailscale IP entry is awkward, try `dell-bubblepath` as the address instead.

## Important Server Paths

- Shared root: `/srv/storage/shared`
- Incoming drop folder: `/srv/storage/shared/Incoming`
- Incoming batch archive: `/srv/storage/shared/BubblePath/incoming-batches`
- Shared BubblePath folder: `/srv/storage/shared/BubblePath`
- Shared backups: `/srv/storage/shared/Backups`
- Server workspace: `/srv/bubblepath`
- Server logs: `/srv/bubblepath/logs`

## Server Commands

These commands now work after login:

```bash
bubblepath-phone-help
bubblepath-session-start
bubblepath-intake-status
bubblepath-share-status
bubblepath-server-status
bubblepath-paths
bubblepath-incoming
bubblepath-batches
bubblepath-batch-files
bubblepath-tree
bubblepath-process-incoming
bubblepath-latest-batch
bubblepath-watch-incoming
bubblepath-backup
bubblepath-backups
```

Short aliases now also exist for phone/SSH sessions:

```bash
bp-help
bp-start
bp-intake
bp-share-status
bp-status
bp-paths
bp-incoming
bp-batches
bp-files
bp-tree
bp-process
bp-latest
bp-watch
bp-backup
bp-backups
bp-share
bp-home
```

### What They Do

- `bubblepath-phone-help`
  - prints the quick phone/server connection details and the current BubblePath command set

- `bubblepath-session-start`
  - gives a compact BubblePath server welcome, quick status, intake snapshot, and recent backup summary

- `bubblepath-intake-status`
  - gives one compact intake snapshot: waiting files, processed batch count, and the latest batch summary

- `bubblepath-share-status`
  - gives a compact view of the key shared BubblePath folders plus overall shared-disk usage

- `bubblepath-server-status`
  - shows host, IP, service status, and free storage

- `bubblepath-paths`
  - prints the important BubblePath server directories

- `bubblepath-incoming`
  - shows the Incoming drop folder and newest items

- `bubblepath-batches`
  - lists the most recent processed incoming-batch folders

- `bubblepath-batch-files`
  - prints the files inside the latest processed incoming batch

- `bubblepath-tree`
  - prints a compact folder tree for `/srv/bubblepath` and `/srv/storage/shared`

- `bubblepath-process-incoming`
  - moves everything currently in `Incoming` into a timestamped batch folder under `BubblePath/incoming-batches`
  - writes a `manifest.txt`
  - updates `/srv/bubblepath/logs/latest-incoming-batch.txt`

- `bubblepath-process-incoming my-label`
  - same as above, but adds a label to the batch folder name

- `bubblepath-latest-batch`
  - prints the latest processed incoming-batch manifest, if one exists

- `bubblepath-backup`
  - creates a timestamped `.tgz` backup of `/srv/bubblepath` in `/srv/storage/shared/Backups`

- `bubblepath-backups`
  - lists the most recent BubblePath server backup archives

- `bubblepath-watch-incoming`
  - watches the `Incoming` folder live and prints new files as they arrive

## Optional

`mosh`, `fzf`, `ncdu`, and `bat` are now installed on the server too, which should make future phone/admin sessions a little nicer. The Ubuntu firewall now also allows the standard `mosh` UDP range (`60000:61000`).

## Server Home Touches

The Ubuntu box now also has:

- `~/.config/bubblepath/WELCOME.txt`
- `~/.bash_aliases` with BubblePath shortcuts
- `~/.tmux.conf` with a few friendlier defaults

The welcome note and `bubblepath-session-start` snapshot now reflect the fuller command set, intake state, shared-storage view, and recent backups together.

## Recommended Workflow

1. Drop raw files into `/srv/storage/shared/Incoming`
2. SSH in from Termius
3. Run:

```bash
bubblepath-incoming
bubblepath-process-incoming data-dump
```

4. Work from the created batch folder in:

```bash
/srv/storage/shared/BubblePath/incoming-batches
```

This keeps the raw handoff tidy and gives each intake session a timestamped home.

## Good Next Server Moves

- add import validation helpers around the incoming batch folders
- add wrapper/cleanup helpers for GPT-style saved responses
- add a simple watch script for the Incoming folder
- later add a tiny local capture endpoint for push-to-BubblePath flows
