# BubblePath Mac Quick Start

## Fastest Launch

Double-click:

`Launch BubblePath.command`

The first launch may build the Mac app. After that it opens:

`dist/BubblePath.app`

## Keep It In The Dock

1. Open `dist/BubblePath.app`.
2. When BubblePath appears in the Dock, right-click its Dock icon.
3. Choose Options, then Keep in Dock.

You can also drag `dist/BubblePath.app` onto the Dock.

When Codex improves the app, it repackages the same `dist/BubblePath.app` path. The Dock icon can stay where it is; relaunching that same icon opens the newest packaged build.

## Manual Launch

```bash
./run-native-mac.sh
```

## Rebuild The App

```bash
./scripts/package-native-mac.sh
```

## What Is Usable Now

- Create and edit bubbles on the Mac canvas.
- Save and reload the local BubblePath vault.
- Autosave protects edits shortly after you stop typing, flushes pending changes when the app leaves the foreground, and flushes again when the app is quitting.
- Search bubbles, tags, sources, files, folders, and captures.
- Delete the selected bubble with the Delete key or the trash button in the detail panel.
- Press Escape to close the selected bubble and get back to the full canvas.
- Press Command-N to create a new bubble in the center of the canvas.
- Press Command-S to force an immediate save to the local BubblePath vault.
- Press Shift-Command-D to duplicate the selected bubble with a small offset.
- Use the duplicate button in the detail panel to branch a thought visually.
- Use the arrow keys to nudge the selected bubble around the canvas.
- Use Command-[ and Command-] to move backward and forward through bubble selection.
- Press Escape with no bubble selected to clear the active search and return to the full web.
- Use the New Bubble button in the utility panel if you want a visible creation control in addition to tap and Command-N.
- Use the Clear Search button in the utility panel whenever you want a mouse-first way back to the full web.
- Capture dropped text, PDFs, HTML, links, images, audio, and video as searchable bubbles.
- Reveal remembered local source files in Finder when they still exist.
- Open or copy captured source URLs.
- Custom BubblePath Dock icon.

## Still Not Final

- This is a serviceable local-first Mac build, not a polished signed installer.
- Dropped media files are captured as searchable provenance and notes, not copied into the vault yet.
- GPT-in-bubbles still depends on API billing/key setup and is not required for basic use.
