# Termius Quick Connect

Last updated: 2026-04-24

## Goal

Reconnect to the BubblePath Ubuntu helper box from a phone quickly, without guessing host details.

## Manual Host Entry

Create a host in Termius with:

- Label: `BubblePath Server`
- Address: `100.120.102.102`
- Username: `millerm`
- Port: `22`
- Auth: password

If the Tailscale IP is awkward, try:

- Address: `dell-bubblepath`

## First Commands To Run

```bash
bp-start
bp-intake
bp-share-status
```

## Useful Shortcuts

```bash
bp-help
bp-start
bp-intake
bp-status
bp-share-status
bp-incoming
bp-batches
bp-files
bp-backups
bp-home
bp-share
```

## If You Want To Check Intake

```bash
bp-intake
bp-batches
bp-files
```

## If You Want To Check Safety

```bash
bp-backups
```
