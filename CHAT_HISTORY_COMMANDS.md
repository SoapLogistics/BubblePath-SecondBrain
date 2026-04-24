# BubblePath Chat History Commands

Use these when you want the terminal-side fallback for preparing ChatGPT history imports.

If you need help deciding whether a file should be imported directly or wrapped first, see:

`CHAT_HISTORY_SHAPE_GUIDE.md`

## Use These In Order

1. Decide whether the JSON can be imported directly or should be wrapped first.
2. If the JSON is already on your clipboard and you do not need a saved file first, you can import it in BubblePathMac with `Command-Shift-I`.
3. If needed, wrap the JSON into a standard BubblePath batch.
4. Validate the final batch.
5. Import it into BubblePath.

## Fastest No-Terminal Path

- If the JSON is already in a full BubblePath batch or one of the directly supported loose shapes, copy it and use `Command-Shift-I` in BubblePathMac.
- The same clipboard import path is also available from `File > Import Clipboard JSON`.
- If you saved a GPT-style response as `.txt`, `.md`, `.markdown`, `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, or `.webarchive`, BubblePathMac's normal `Import` flow now accepts that too.
- BubblePathMac now checks that clipboard content is valid JSON before it attempts the import.
- BubblePathMac can also strip outer ```json code fences automatically during clipboard import.
- BubblePathMac can also extract one fenced JSON block out of a larger GPT-style response during clipboard import.
- BubblePathMac now also chooses the supported fenced BubblePath payload when a GPT-style response starts with an irrelevant embedded JSON block and only later includes the real fenced BubblePath batch.
- BubblePathMac now prefers the fenced JSON block that actually looks like BubblePath data when a GPT-style response contains more than one fenced JSON block.
- BubblePathMac can also pull out one raw embedded JSON object or array from a larger GPT-style response during clipboard import.
- BubblePathMac now also prefers the embedded JSON chunk that actually looks like BubblePath data when a GPT-style response contains more than one raw embedded JSON object or array.
- BubblePathMac now also chooses the supported embedded BubblePath payload when a GPT-style response starts with an irrelevant fenced JSON block and only later includes the real embedded BubblePath batch.
- If you want a saved normalized artifact first, use the wrapper flow below instead.

## Validate A BubblePath Batch

```sh
swift scripts/validate-chat-history-batch.swift your-file.json
```

If you run the validator against a loose root-object, root-array, or single-entry chat-history file, it now tells you that BubblePathMac can import it directly or that you can wrap it first.
The validator now also reports whether it read direct JSON, fenced GPT-style JSON, or embedded GPT-style JSON.
The validator now also says when it skipped earlier unrelated JSON before choosing the BubblePath payload.
The validator and wrapper now accept `.doc`, `.docx`, `.odt`, `.rtf`, `.html`, `.htm`, `.pdf`, and `.webarchive` GPT response files too, not just plain `.json`, `.txt`, and markdown.

## Validate Multiple Files

```sh
swift scripts/validate-chat-history-batch.swift first.json second.json third.json
```

## Validate A Folder Through The Command Helper

```sh
./Validate\ Chat\ History.command path/to/folder
```

## Wrap A Loose Shape Into A BubblePath Batch

```sh
swift scripts/wrap-chat-history-batch.swift your-file.json
```

The wrapper now tells you what kind of input it detected before it writes the normalized batch.
It also reports how many entries it detected, which is a quick sanity check before import.
If the input came from a GPT-style response file, the wrapper now also says whether it extracted fenced or embedded JSON before wrapping.
The wrapper now also says when it skipped earlier unrelated JSON before choosing the BubblePath payload.
On mixed embedded-plus-fence GPT-style responses, the wrapper now also chooses the supported fenced BubblePath payload instead of getting stuck on an earlier irrelevant embedded block.
On multi-embedded GPT-style responses, the wrapper now also prefers the embedded chunk that actually looks like BubblePath data instead of the first irrelevant JSON block.
On multi-fence GPT-style responses, the wrapper now also prefers the fenced block that actually looks like BubblePath data instead of the first irrelevant JSON block.
On mixed fence-plus-embedded GPT-style responses, the wrapper now also chooses the supported embedded BubblePath payload instead of getting stuck on an earlier irrelevant fenced block.

## Wrap A File With A Custom Output Path

```sh
swift scripts/wrap-chat-history-batch.swift input.json output.json
```

## Wrap A Folder Through The Command Helper

```sh
./Wrap\ Chat\ History.command path/to/folder
```

## Quick Rule

- Full `chat-history-batch`: validate, then import
- Root object with `chats`: import directly, use `Command-Shift-I`, or wrap first
- Root array: import directly, use `Command-Shift-I`, or wrap first
- Single entry: import directly, use `Command-Shift-I`, or wrap first
- If you want the cleanest artifact first: wrap, then validate
