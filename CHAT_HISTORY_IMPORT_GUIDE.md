# BubblePath Chat History Import Guide

Use this guide when preparing old ChatGPT conversations for BubblePath.

## Goal

Turn old conversations into many small, searchable bubbles instead of one giant archive dump.

## Use This File

Start from:

`chat-history-batch-template.json`

BubblePath can now import that format directly.

If you are unsure whether a file should be imported directly or wrapped first, see:

`CHAT_HISTORY_SHAPE_GUIDE.md`

If you want the exact terminal-side commands in one place, see:

`CHAT_HISTORY_COMMANDS.md`

## Rules For Preparing Data

- Prefer many small bubbles over a few large ones.
- Keep each bubble focused on one idea, question, principle, decision, or reference unit.
- Keep titles short and useful.
- Use tags generously but meaningfully.
- Use only these `bubbleType` values:
  - `thought`
  - `question`
  - `decision`
  - `seed`
  - `file`
  - `chat`

## Suggested Meaning Of Bubble Types

- `thought`: a normal idea or reflection
- `question`: an unresolved issue or problem
- `decision`: a settled conclusion
- `seed`: a core truth, principle, or foundational claim
- `file`: reference-style material
- `chat`: something still conversational in tone

## Import Steps

1. Ask ChatGPT to distill your old conversations into the `chat-history-batch` JSON format.
2. Either:
   - save the result as a `.json` file, or
   - save the result as a `.txt`, `.md`, or `.markdown` file if it still includes GPT wrapper text around the JSON, or
   - save the result as a `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, or `.webarchive` file if the GPT response was preserved in a richer format and still contains readable JSON text, or
   - copy the JSON to the clipboard if you want to import it straight into BubblePathMac with `Command-Shift-I`
3. Optional but recommended: validate it locally with:

   `swift scripts/validate-chat-history-batch.swift your-file.json`

   or drag the JSON file onto:

   `Validate Chat History.command`

   The validator command can check more than one JSON file at once, or a whole folder of JSON files, and reports a pass/fail summary for all of them.

   If you want a quick failure example, try:

   `chat-history-batch-invalid-example.json`

   If you want the smallest valid example, try:

   `chat-history-batch-minimal-example.json`

   If you want a single-entry object example that still needs wrapping, try:

   `chat-history-single-entry-example.json`

   If you want a root-array example that still needs wrapping, try:

   `chat-history-array-example.json`

   If you want a root-object example with a `chats` array that still needs wrapping, try:

   `chat-history-object-example.json`

   If you want a GPT-style markdown response with fenced BubblePath JSON inside it, try:

   `chat-history-gpt-fenced-example.md`

   If you want a GPT-style markdown response with raw embedded BubblePath JSON after some prose, try:

   `chat-history-gpt-embedded-example.md`

   If you want a GPT-style plain-text response with a short explanation before the BubblePath JSON, try:

   `chat-history-gpt-plain-text-example.txt`

   If you want a GPT-style saved DOCX response with readable BubblePath JSON inside it, try:

   `chat-history-gpt-docx-example.docx`

   If you want a GPT-style saved DOC response with readable BubblePath JSON inside it, try:

   `chat-history-gpt-doc-example.doc`

   If you want a GPT-style saved ODT response with readable BubblePath JSON inside it, try:

   `chat-history-gpt-odt-example.odt`

   If you want a GPT-style saved rich-text response with readable BubblePath JSON inside it, try:

   `chat-history-gpt-rtf-example.rtf`

   If you want a GPT-style saved HTML response with fenced BubblePath JSON inside readable page text, try:

   `chat-history-gpt-html-example.html`

   If you want a GPT-style saved PDF response with readable BubblePath JSON inside it, try:

   `chat-history-gpt-pdf-example.pdf`

   If you want a GPT-style saved webarchive response with readable BubblePath JSON inside it, try:

   `chat-history-gpt-webarchive-example.webarchive`

   If you want a GPT-style response with an irrelevant embedded JSON block before the real fenced BubblePath batch, try:

   `chat-history-gpt-embedded-plus-fence-example.md`

   If you want a GPT-style response with an irrelevant fenced JSON block before the real embedded BubblePath batch, try:

   `chat-history-gpt-fence-plus-embedded-example.md`

   If you want a GPT-style response with more than one raw embedded JSON object or array, try:

   `chat-history-gpt-multi-embedded-example.txt`

   If you want a GPT-style response with more than one fenced JSON block, try:

   `chat-history-gpt-multi-fence-example.md`

   If ChatGPT gives you only a `chats` array or a single chat-entry object instead of a full batch envelope, normalize it first with:

   `swift scripts/wrap-chat-history-batch.swift your-file.json`

   or drag the file onto:

   `Wrap Chat History.command`

   The wrapper command can also accept a whole folder of JSON files, skips existing `*-wrapped.json` outputs, validates the wrapped output files automatically, tells you clearly when a folder only contains already-wrapped files, and reports how many wrapped files it skipped in mixed runs.

4. In BubblePath, either:
   - use Import,
   - use Import on a saved `.json`, `.txt`, `.md`, `.markdown`, `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, or `.webarchive` GPT response file,
   - drag a saved `.json`, `.txt`, `.md`, `.markdown`, `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, or `.webarchive` GPT response file onto the canvas, or
   - paste-ready JSON can be imported from the clipboard with `Command-Shift-I` or `File > Import Clipboard JSON`
5. BubblePath will turn the entries into structured bubbles with tags and suggested types.

For common loose shapes like a root object with `chats`, a root array, or a single entry, it is now reasonable to try a direct BubblePathMac import first and only wrap if you want the cleaner artifact or the direct import is not what you wanted.

## Notes

- This is safer than importing whole vault JSON unless you really mean to replace the active vault.
- The importer keeps `chat-history-batch` separate from full-vault imports.
- Suggested tags and suggested types are supported.
- Top-level `sourceApp` is optional and can preserve the upstream tool or workflow name for imported batches.
- Source chat title, source chat ID, and source URL can be preserved per entry.
- The validator now catches wrong top-level `app`/`kind`/`version` values, bad batch metadata, missing titles/excerpts, invalid `bubbleType` values, bad `tags` arrays, invalid `sourceURL` values, and invalid `capturedAt` timestamps.
- If you accidentally validate a root-object, root-array, or single-entry chat-history file instead of a full batch, the validator now tells you that BubblePathMac can import it directly or that you can wrap it first.
- Clipboard import now checks that the pasted content is valid JSON before handing it to the BubblePath importer, can strip outer ```json code fences automatically, can extract one fenced JSON block from a larger GPT-style response, and can also pull out one raw embedded JSON object or array from a larger response.
- The workspace now includes GPT-style fenced, embedded, plain-text, saved-DOC, saved-DOCX, saved-ODT, saved-RTF, saved-HTML, saved-PDF, saved-webarchive, embedded-plus-fence, fence-plus-embedded, multi-embedded, and multi-fence response examples too, so the tolerant import paths can be tested without inventing your own sample text first.
- When a GPT-style response contains an irrelevant embedded JSON block before a real fenced BubblePath batch, BubblePath, the validator, and the wrapper now choose the supported fenced BubblePath payload instead of getting stuck on the first embedded JSON block.
- When a GPT-style response contains more than one fenced JSON block, BubblePath, the validator, and the wrapper now all prefer the fenced block that actually looks like BubblePath data instead of blindly taking the first valid JSON block.
- When a GPT-style response contains more than one raw embedded JSON object or array, BubblePath, the validator, and the wrapper now all prefer the embedded chunk that actually looks like BubblePath data instead of blindly taking the first valid JSON block.
- When a GPT-style response contains an irrelevant fenced JSON block before a real embedded BubblePath batch, BubblePath, the validator, and the wrapper now choose the supported embedded BubblePath payload instead of getting stuck on the first fenced JSON block.
