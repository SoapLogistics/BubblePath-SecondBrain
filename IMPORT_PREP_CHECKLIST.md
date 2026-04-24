# BubblePath Import Prep Checklist

Use this before importing old ChatGPT material into BubblePath.

## 1. Build Or Distill The Batch

- Start from `chat-history-batch-template.json`
- Use `CHAT_HISTORY_SHAPE_GUIDE.md` if you are unsure whether to import directly or wrap first
- Use `CHAT_HISTORY_COMMANDS.md` if you want the exact validate/wrap commands in one place
- Use `CHAT_HISTORY_DISTILL_PROMPT.txt` as the paste-ready prompt for ChatGPT
- Keep each entry focused on one idea
- Use only allowed `bubbleType` values:
  - `thought`
  - `question`
  - `decision`
  - `seed`
  - `file`
  - `chat`

## 2. Validate The JSON

Use either:

- `Validate Chat History.command`
- `swift scripts/validate-chat-history-batch.swift your-file.json`

If the JSON shape is close but not wrapped correctly, normalize it first with:

- `swift scripts/wrap-chat-history-batch.swift your-file.json`
- `Wrap Chat History.command`

The wrapper command can also take a folder of JSON files.
It skips existing `*-wrapped.json` outputs so reruns stay tidy, validates the wrapped outputs automatically, reports clearly when a folder only contains already-wrapped files, and now shows a skip count in mixed runs too.

You can also validate a whole folder of JSON files.

## 3. Compare Good And Bad Examples

- Good shape: `chat-history-batch-template.json`
- Smallest valid shape: `chat-history-batch-minimal-example.json`
- Root-object shape with `chats` that needs wrapping: `chat-history-object-example.json`
- Single-entry shape that needs wrapping: `chat-history-single-entry-example.json`
- Root-array shape that needs wrapping: `chat-history-array-example.json`
- GPT-style fenced response example: `chat-history-gpt-fenced-example.md`
- GPT-style embedded response example: `chat-history-gpt-embedded-example.md`
- GPT-style plain-text response example: `chat-history-gpt-plain-text-example.txt`
- GPT-style saved-DOC response example: `chat-history-gpt-doc-example.doc`
- GPT-style saved-DOCX response example: `chat-history-gpt-docx-example.docx`
- GPT-style saved-ODT response example: `chat-history-gpt-odt-example.odt`
- GPT-style saved-RTF response example: `chat-history-gpt-rtf-example.rtf`
- GPT-style saved-HTML response example: `chat-history-gpt-html-example.html`
- GPT-style saved-PDF response example: `chat-history-gpt-pdf-example.pdf`
- GPT-style saved-webarchive response example: `chat-history-gpt-webarchive-example.webarchive`
- GPT-style embedded-plus-fence response example: `chat-history-gpt-embedded-plus-fence-example.md`
- GPT-style fence-plus-embedded response example: `chat-history-gpt-fence-plus-embedded-example.md`
- GPT-style multi-embedded response example: `chat-history-gpt-multi-embedded-example.txt`
- GPT-style multi-fence response example: `chat-history-gpt-multi-fence-example.md`
- Bad shape: `chat-history-batch-invalid-example.json`
- Prompt source: `CHAT_HISTORY_DISTILL_PROMPT.txt`

For GPT-style responses with an irrelevant embedded JSON block before a real fenced BubblePath batch, BubblePath, the validator, and the wrapper now all choose the supported fenced BubblePath payload instead of getting stuck on the first embedded block.

For GPT-style responses with more than one raw embedded JSON object or array, BubblePath, the validator, and the wrapper now all prefer the embedded chunk that actually looks like BubblePath data.

For GPT-style responses with more than one fenced JSON block, BubblePath, the validator, and the wrapper now all prefer the fenced block that actually looks like BubblePath data.

For GPT-style responses with an irrelevant fenced JSON block before a real embedded BubblePath batch, BubblePath, the validator, and the wrapper now all choose the supported embedded BubblePath payload instead of getting stuck on the first fenced block.

For the loose root-object, root-array, and single-entry shapes, it is now reasonable to try a direct BubblePathMac import first and only wrap if you want the cleaner artifact or the direct import is not what you wanted.

## 4. Import Into BubblePath

- Use the Import button in the Mac app
- or use Import on a saved `.json`, `.txt`, `.md`, `.markdown`, `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, or `.webarchive` GPT response file
- or drag a saved `.json`, `.txt`, `.md`, `.markdown`, `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, or `.webarchive` GPT response file onto the canvas
- or copy the JSON and press `Command-Shift-I` to import from the clipboard
- or use `File > Import Clipboard JSON`

## 5. If Something Goes Wrong

- Empty batch: BubblePath now says the batch was empty
- Malformed batch: BubblePath now says the JSON was malformed
- Invalid chat entries: BubblePath now says the batch had invalid entries
- Wrong envelope shape: the validator now catches incorrect top-level `app`, `kind`, or `version` values before import
- Bad top-level batch metadata: the validator now catches bad `sourceApp`, `sourceChatTitle`, `sourceChatID`, and `sourceURL` values before import
- Mixed imports: BubblePath now names specific skipped/problem files when it can
- Clipboard import: BubblePath now says clearly if the clipboard is empty, not valid UTF-8 text, or not valid JSON, can strip outer ```json code fences automatically, can extract one fenced JSON block from a larger GPT-style response, and can also pull out one raw embedded JSON object or array from a larger response
- Saved GPT response files, including richer `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, and `.webarchive` ones: if BubblePath still finds no usable BubblePath JSON, it now points you toward the GPT fenced/embedded example files or the shape guide instead of only failing silently or vaguely, even on the saved-webpage, saved-Word, and saved-OpenDocument paths

## 6. After Import

- Check the `Source Conversations` lane
- Check recent captures
- Search by conversation title or ID
- Open a bubble and verify source conversation metadata is present
