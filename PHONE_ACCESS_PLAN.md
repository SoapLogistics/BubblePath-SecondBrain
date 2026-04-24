# BubblePath Phone Access Plan

Last updated: 2026-04-24

## Goal

Be able to reach BubblePath from a phone in a way that feels conversational and continuous, not like operating a Linux box by hand every time.

## What Exists Now

- The native Mac app is still the main BubblePath experience.
- The Ubuntu helper box is reachable over Tailscale.
- Termius can already be used as a first phone doorway into the server.
- The server now has a small BubblePath command set:
  - `bubblepath-phone-help`
  - `bubblepath-session-start`
  - `bubblepath-intake-status`
  - `bubblepath-share-status`
  - `bubblepath-server-status`
  - `bubblepath-paths`
  - `bubblepath-incoming`
  - `bubblepath-batches`
  - `bubblepath-batch-files`
  - `bubblepath-tree`
  - `bubblepath-process-incoming`
  - `bubblepath-latest-batch`
  - `bubblepath-backup`
  - `bubblepath-backups`
  - `bubblepath-watch-incoming`
- The server now also has shorter alias forms for phone sessions:
  - `bp-help`
  - `bp-start`
  - `bp-intake`
  - `bp-share-status`
  - `bp-status`
  - `bp-paths`
  - `bp-incoming`
  - `bp-batches`
  - `bp-files`
  - `bp-tree`
  - `bp-process`
  - `bp-latest`
  - `bp-watch`
  - `bp-backup`
  - `bp-backups`
  - `bp-share`
  - `bp-home`
- `mosh` is installed on the server and the Ubuntu firewall now allows the standard `mosh` UDP range (`60000:61000`) for future phone-friendly shell use

## What Termius Is Good For

- checking server health
- moving around shared storage
- batching incoming files
- triggering cleanup/backups
- keeping BubblePath's helper machine under control from a phone

## What Termius Is Not

- not the final iPhone BubblePath experience
- not the native canvas
- not a true Codex-on-phone replacement

It is a bridge, not the destination.

## Near-Term Path

1. Keep the Mac app as the main BubblePath client
2. Keep growing the Ubuntu box as the always-on helper
3. Make the server commands cleaner and easier to use from a phone
4. Add incoming-processing helpers for saved GPT outputs and BubblePath import batches

## Likely Next Step Toward A Better Phone Experience

Build a tiny phone-friendly BubblePath server surface before trying to jump straight to a full iPhone app.

Examples:

- a small local web page for server status and incoming batches
- a simple upload page for dropped GPT responses
- a text-first control surface for import/cleanup actions
- later, a real iPhone-native BubblePath companion

## Design Rule

The phone path should gradually move from:

- SSH and manual commands

toward:

- simple actions
- readable status
- lightweight upload/capture flows
- continuity with the main BubblePath world
