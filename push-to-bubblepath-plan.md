# Push To BubblePath Plan

This is the first product direction for getting outside material into BubblePath without turning the app into a browser.

## Core Push Flows

1. Push webpage to BubblePath
2. Push selected text to BubblePath
3. Push ChatGPT exchange to BubblePath
4. Push story draft or article into an existing bubble

## First Native Shape

### Mac

- Safari share extension or Safari app extension
- System Share Sheet target for URLs and text
- Creates a new bubble or appends to an existing bubble

### iPhone

- Share extension from Safari and other apps
- Send URL, title, selected text, and source app into BubblePath

## Capture Payload

The capture payload should be simple and portable:

- source type: webpage, text selection, chat export, note
- source title
- source URL if present
- captured text
- captured at date
- suggested bubble title
- optional target bubble ID

This payload now exists in both native code paths:

- `NativeMac/BubblePathMac/Sources/BubbleCapturePayload.swift`
- `BubblePathPhone/Sources/Models/BubbleCapturePayload.swift`

## ChatGPT To BubblePath

The honest version is not "direct account sync."

The first realistic version is:

- user shares or copies a ChatGPT exchange
- BubblePath receives the text and source URL if available
- BubblePath creates a bubble titled from the exchange
- later we can support "append to existing bubble"

## BubblePath To ChatGPT

This should be treated as a lighter handoff:

- copy bubble as prompt
- open ChatGPT with a prepared prompt if feasible
- do not promise direct write access into the user's ChatGPT history

## Shared Ingestion Goal

Both the Mac app and the iPhone app should eventually use the same capture model so a webpage pushed on the phone can become the same kind of bubble as a webpage pushed on the Mac.

## Good First Build Order

1. Define shared capture payload model
2. Add manual import action in the Mac app
3. Add Share Sheet ingestion on iPhone
4. Add Safari extension on Mac
5. Add "append to existing bubble" flow

## Current Progress

- Shared capture payload model exists on Mac
- Shared capture payload model exists on iPhone
- Native Mac app has a manual Capture sheet for pasted material
- Native iPhone app now has a manual Capture sheet for pasted material
- Next most useful build: iPhone Share Sheet ingestion using the same payload
