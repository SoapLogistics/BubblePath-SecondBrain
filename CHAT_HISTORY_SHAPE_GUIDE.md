# BubblePath Chat History Shape Guide

Use this when deciding whether a chat-history JSON file can be imported directly or should be wrapped first.

## Directly Supported In BubblePath

BubblePathMac can now import these shapes directly:

1. Full BubblePath `chat-history-batch`
2. Root object with a `chats` array
3. Root array of chat entries
4. Single chat entry object

## When To Still Use The Wrapper

Use `Wrap Chat History.command` or:

`swift scripts/wrap-chat-history-batch.swift your-file.json`

when you want to:

- convert a loose shape into a standard `chat-history-batch` file first
- validate the wrapped result immediately afterward
- batch-convert a whole folder into sibling `-wrapped.json` files
- keep a normalized import artifact around before handing files to BubblePath

## Quick Rule

- If you want the fastest path, try importing the JSON directly into BubblePathMac first.
- If the JSON is already on your clipboard, you can use `Command-Shift-I` instead of saving a file first.
- If the app accepts it cleanly, you are done.
- If you want the safest, clearest artifact first, wrap it and then import the wrapped file.

If you want the exact terminal-side commands for those paths, see:

`CHAT_HISTORY_COMMANDS.md`

## Example Files

- Full batch: `chat-history-batch-template.json`
- Minimal valid batch: `chat-history-batch-minimal-example.json`
- Root object with `chats`: `chat-history-object-example.json`
- Root array: `chat-history-array-example.json`
- Single entry: `chat-history-single-entry-example.json`
- GPT-style fenced response: `chat-history-gpt-fenced-example.md`
- GPT-style embedded response: `chat-history-gpt-embedded-example.md`
- GPT-style plain-text response: `chat-history-gpt-plain-text-example.txt`
- GPT-style saved-DOC response: `chat-history-gpt-doc-example.doc`
- GPT-style saved-DOCX response: `chat-history-gpt-docx-example.docx`
- GPT-style saved-ODT response: `chat-history-gpt-odt-example.odt`
- GPT-style saved-RTF response: `chat-history-gpt-rtf-example.rtf`
- GPT-style saved-HTML response: `chat-history-gpt-html-example.html`
- GPT-style saved-PDF response: `chat-history-gpt-pdf-example.pdf`
- GPT-style saved-webarchive response: `chat-history-gpt-webarchive-example.webarchive`
- GPT-style embedded-plus-fence response: `chat-history-gpt-embedded-plus-fence-example.md`
- GPT-style fence-plus-embedded response: `chat-history-gpt-fence-plus-embedded-example.md`
- GPT-style multi-embedded response: `chat-history-gpt-multi-embedded-example.txt`
- GPT-style multi-fence response: `chat-history-gpt-multi-fence-example.md`
- Invalid example: `chat-history-batch-invalid-example.json`

If a GPT-style response contains an irrelevant embedded JSON block before a real fenced BubblePath batch, BubblePath, the validator, and the wrapper now all choose the supported fenced BubblePath payload instead of stopping at the first embedded block.

If a GPT-style response contains more than one raw embedded JSON object or array, BubblePath, the validator, and the wrapper now all prefer the embedded chunk that actually looks like BubblePath import data.

If a GPT-style response contains more than one fenced JSON block, BubblePath, the validator, and the wrapper now all prefer the fenced block that actually looks like BubblePath import data.

If a GPT-style response contains an irrelevant fenced JSON block before a real embedded BubblePath batch, BubblePath, the validator, and the wrapper now all choose the supported embedded BubblePath payload instead of stopping at the first fenced block.
