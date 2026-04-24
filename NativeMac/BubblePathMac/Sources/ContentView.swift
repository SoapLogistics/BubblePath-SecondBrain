import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: BubbleStore
    @EnvironmentObject private var cloudSync: CloudSyncStatusStore
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingCaptureSheet = false
    @State private var captureSeed: CaptureImportSeed?
    @State private var importDropTargeted = false
    @State private var textDropTargeted = false

    var body: some View {
        ZStack {
            BubbleCanvasBackground()

            BubbleMapView()
                .padding(28)

            overlayChrome

            if importDropTargeted || textDropTargeted {
                DropTargetOverlay(
                    title: textDropTargeted ? "Capture this text" : "Drop into BubblePath",
                    detail: textDropTargeted
                        ? "Drop it here to turn the selection into a bubble."
                        : "Drop webpage links, text files, saved GPT/webpage/document files, media, capture JSON, or vault JSON into your thought web."
                )
            }
        }
        .frame(minWidth: 1080, minHeight: 720)
        .dropDestination(for: URL.self) { urls, _ in
            handleDroppedURLs(urls)
            return true
        } isTargeted: { isTargeted in
            importDropTargeted = isTargeted
        }
        .dropDestination(for: String.self) { strings, _ in
            handleDroppedText(strings)
            return true
        } isTargeted: { isTargeted in
            textDropTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [
                .json,
                .plainText,
                .text,
                .utf8PlainText,
                .rtf,
                .pdf,
                UTType(filenameExtension: "doc") ?? .plainText,
                UTType(filenameExtension: "docx") ?? .plainText,
                UTType(filenameExtension: "odt") ?? .plainText,
                UTType(filenameExtension: "webarchive") ?? .plainText,
                UTType(filenameExtension: "html") ?? .plainText,
                UTType(filenameExtension: "htm") ?? .plainText,
                UTType(filenameExtension: "md") ?? .plainText,
                UTType(filenameExtension: "markdown") ?? .plainText
            ],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: BubblePathJSONDocument(document: store.currentDocument()),
            contentType: .json,
            defaultFilename: "bubblepath-\(dateStamp())"
        ) { result in
            handleExport(result)
        }
        .sheet(isPresented: $showingCaptureSheet, onDismiss: {
            captureSeed = nil
        }) {
            CaptureImportSheet(seed: captureSeed)
                .environmentObject(store)
        }
        .onDeleteCommand {
            guard store.selectedBubble != nil else { return }
            HapticsService.shared.perform(.select)
            store.deleteSelectedBubble()
        }
        .onExitCommand {
            if store.selectedBubble != nil {
                HapticsService.shared.perform(.select)
                store.clearSelection()
            } else if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HapticsService.shared.perform(.select)
                store.clearSearch()
            }
        }
        .focusable()
        .onMoveCommand { direction in
            guard store.selectedBubble != nil else { return }
            switch direction {
            case .left:
                store.nudgeSelectedBubble(xDelta: -1.5, yDelta: 0)
            case .right:
                store.nudgeSelectedBubble(xDelta: 1.5, yDelta: 0)
            case .up:
                store.nudgeSelectedBubble(xDelta: 0, yDelta: -1.5)
            case .down:
                store.nudgeSelectedBubble(xDelta: 0, yDelta: 1.5)
            @unknown default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flushAutosave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bubblePathImportClipboardJSON)) { _ in
            importJSONFromClipboard()
        }
    }

    private var overlayChrome: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 14) {
                    HeroPanel()
                    Spacer()
                    if store.selectedBubble == nil {
                        HintPanel(
                            title: searchModeActive ? "Search the web" : "Start with a thought",
                            detail: searchModeActive
                                ? "Type a word like bible and the matching bubbles will float into view."
                                : "Tap anywhere in the open space to place a new bubble."
                        )
                    }
                }
                .padding(28)

                VStack {
                    HStack {
                        Spacer()
                        UtilityPanel(
                            onNewBubble: {
                                HapticsService.shared.perform(.create)
                                store.createBubbleAtCanvasCenter()
                            },
                            onRevealImportPrepSet: {
                                openSupportFiles(
                                    named: [
                                        "IMPORT_PREP_CHECKLIST.md",
                                        "CHAT_HISTORY_IMPORT_GUIDE.md",
                                        "CHAT_HISTORY_SHAPE_GUIDE.md",
                                        "CHAT_HISTORY_COMMANDS.md",
                                        "SERVER_COMMANDS.md",
                                        "SERVER_QUICK_START.md",
                                        "PHONE_ACCESS_PLAN.md",
                                        "TERMIUS_QUICK_CONNECT.md",
                                        "CHAT_HISTORY_DISTILL_PROMPT.txt",
                                        "chat-history-batch-template.json",
                                        "chat-history-batch-minimal-example.json",
                                        "chat-history-object-example.json",
                                        "chat-history-array-example.json",
                                        "chat-history-single-entry-example.json",
                                        "chat-history-gpt-fenced-example.md",
                                        "chat-history-gpt-embedded-example.md",
                                        "chat-history-gpt-plain-text-example.txt",
                                        "chat-history-gpt-doc-example.doc",
                                        "chat-history-gpt-docx-example.docx",
                                        "chat-history-gpt-odt-example.odt",
                                        "chat-history-gpt-rtf-example.rtf",
                                        "chat-history-gpt-html-example.html",
                                        "chat-history-gpt-pdf-example.pdf",
                                        "chat-history-gpt-webarchive-example.webarchive",
                                        "chat-history-gpt-embedded-plus-fence-example.md",
                                        "chat-history-gpt-fence-plus-embedded-example.md",
                                        "chat-history-gpt-multi-fence-example.md",
                                        "chat-history-gpt-multi-embedded-example.txt",
                                        "chat-history-batch-invalid-example.json",
                                        "Validate Chat History.command",
                                        "Wrap Chat History.command"
                                    ],
                                    openAction: { urls in
                                        NSWorkspace.shared.activateFileViewerSelecting(urls)
                                        return true
                                    },
                                    successStatus: "Revealed the full chat-history import prep set."
                                )
                            },
                            onOpenImportGuide: {
                                openSupportFile(
                                    named: "CHAT_HISTORY_IMPORT_GUIDE.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the chat-history import guide."
                                )
                            },
                            onCopyImportGuide: {
                                copySupportTextFile(
                                    named: "CHAT_HISTORY_IMPORT_GUIDE.md",
                                    successStatus: "Copied the chat-history import guide."
                                )
                            },
                            onOpenImportChecklist: {
                                openSupportFile(
                                    named: "IMPORT_PREP_CHECKLIST.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the import prep checklist."
                                )
                            },
                            onCopyImportChecklist: {
                                copySupportTextFile(
                                    named: "IMPORT_PREP_CHECKLIST.md",
                                    successStatus: "Copied the import prep checklist."
                                )
                            },
                            onOpenServerQuickStart: {
                                openSupportFile(
                                    named: "SERVER_QUICK_START.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the BubblePath server quick start."
                                )
                            },
                            onCopyServerQuickStart: {
                                copySupportTextFile(
                                    named: "SERVER_QUICK_START.md",
                                    successStatus: "Copied the BubblePath server quick start."
                                )
                            },
                            onOpenPhoneAccessPlan: {
                                openSupportFile(
                                    named: "PHONE_ACCESS_PLAN.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the BubblePath phone access plan."
                                )
                            },
                            onCopyPhoneAccessPlan: {
                                copySupportTextFile(
                                    named: "PHONE_ACCESS_PLAN.md",
                                    successStatus: "Copied the BubblePath phone access plan."
                                )
                            },
                            onOpenServerCommandsGuide: {
                                openSupportFile(
                                    named: "SERVER_COMMANDS.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the BubblePath server commands guide."
                                )
                            },
                            onCopyServerCommandsGuide: {
                                copySupportTextFile(
                                    named: "SERVER_COMMANDS.md",
                                    successStatus: "Copied the BubblePath server commands guide."
                                )
                            },
                            onOpenTermiusQuickConnect: {
                                openSupportFile(
                                    named: "TERMIUS_QUICK_CONNECT.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the Termius quick connect guide."
                                )
                            },
                            onCopyTermiusQuickConnect: {
                                copySupportTextFile(
                                    named: "TERMIUS_QUICK_CONNECT.md",
                                    successStatus: "Copied the Termius quick connect guide."
                                )
                            },
                            onOpenChatHistoryShapeGuide: {
                                openSupportFile(
                                    named: "CHAT_HISTORY_SHAPE_GUIDE.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the chat-history shape guide."
                                )
                            },
                            onCopyChatHistoryShapeGuide: {
                                copySupportTextFile(
                                    named: "CHAT_HISTORY_SHAPE_GUIDE.md",
                                    successStatus: "Copied the chat-history shape guide."
                                )
                            },
                            onOpenChatHistoryCommandsGuide: {
                                openSupportFile(
                                    named: "CHAT_HISTORY_COMMANDS.md",
                                    openAction: { url in NSWorkspace.shared.open(url) },
                                    successStatus: "Opened the chat-history commands guide."
                                )
                            },
                            onCopyChatHistoryCommandsGuide: {
                                copySupportTextFile(
                                    named: "CHAT_HISTORY_COMMANDS.md",
                                    successStatus: "Copied the chat-history commands guide."
                                )
                            },
                            onRevealDistillPrompt: {
                                openSupportFile(
                                    named: "CHAT_HISTORY_DISTILL_PROMPT.txt",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the chat-history distill prompt."
                                )
                            },
                            onCopyDistillPrompt: {
                                copySupportTextFile(
                                    named: "CHAT_HISTORY_DISTILL_PROMPT.txt",
                                    successStatus: "Copied the chat-history distill prompt."
                                )
                            },
                            onRevealImportTemplate: {
                                openSupportFile(
                                    named: "chat-history-batch-template.json",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the chat-history import template."
                                )
                            },
                            onCopyImportTemplate: {
                                copySupportTextFile(
                                    named: "chat-history-batch-template.json",
                                    successStatus: "Copied the chat-history import template."
                                )
                            },
                            onRevealImportValidator: {
                                openSupportFile(
                                    named: "Validate Chat History.command",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the chat-history validator command."
                                )
                            },
                            onRevealImportWrapper: {
                                openSupportFile(
                                    named: "Wrap Chat History.command",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the chat-history wrapper command."
                                )
                            },
                            onRevealInvalidChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-batch-invalid-example.json",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the invalid chat-history example."
                                )
                            },
                            onRevealMinimalChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-batch-minimal-example.json",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the minimal chat-history example."
                                )
                            },
                            onCopyMinimalChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-batch-minimal-example.json",
                                    successStatus: "Copied the minimal chat-history example."
                                )
                            },
                            onRevealArrayChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-array-example.json",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the array chat-history example."
                                )
                            },
                            onCopyArrayChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-array-example.json",
                                    successStatus: "Copied the array chat-history example."
                                )
                            },
                            onRevealObjectChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-object-example.json",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the object chat-history example."
                                )
                            },
                            onCopyObjectChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-object-example.json",
                                    successStatus: "Copied the object chat-history example."
                                )
                            },
                            onRevealSingleEntryChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-single-entry-example.json",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the single-entry chat-history example."
                                )
                            },
                            onCopySingleEntryChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-single-entry-example.json",
                                    successStatus: "Copied the single-entry chat-history example."
                                )
                            },
                            onRevealGPTFencedChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-fenced-example.md",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT fenced chat-history example."
                                )
                            },
                            onCopyGPTFencedChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-fenced-example.md",
                                    successStatus: "Copied the GPT fenced chat-history example."
                                )
                            },
                            onRevealGPTEmbeddedChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-embedded-example.md",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT embedded chat-history example."
                                )
                            },
                            onCopyGPTEmbeddedChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-embedded-example.md",
                                    successStatus: "Copied the GPT embedded chat-history example."
                                )
                            },
                            onRevealGPTPlainTextChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-plain-text-example.txt",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT plain-text chat-history example."
                                )
                            },
                            onCopyGPTPlainTextChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-plain-text-example.txt",
                                    successStatus: "Copied the GPT plain-text chat-history example."
                                )
                            },
                            onRevealGPTDOCChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-doc-example.doc",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT DOC chat-history example."
                                )
                            },
                            onCopyGPTDOCChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-doc-example.doc",
                                    successStatus: "Copied the GPT DOC chat-history example."
                                )
                            },
                            onRevealGPTDOCXChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-docx-example.docx",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT DOCX chat-history example."
                                )
                            },
                            onCopyGPTDOCXChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-docx-example.docx",
                                    successStatus: "Copied the GPT DOCX chat-history example."
                                )
                            },
                            onRevealGPTODTChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-odt-example.odt",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT ODT chat-history example."
                                )
                            },
                            onCopyGPTODTChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-odt-example.odt",
                                    successStatus: "Copied the GPT ODT chat-history example."
                                )
                            },
                            onRevealGPTRTFChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-rtf-example.rtf",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT RTF chat-history example."
                                )
                            },
                            onCopyGPTRTFChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-rtf-example.rtf",
                                    successStatus: "Copied the GPT RTF chat-history example."
                                )
                            },
                            onRevealGPTHTMLChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-html-example.html",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT HTML chat-history example."
                                )
                            },
                            onCopyGPTHTMLChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-html-example.html",
                                    successStatus: "Copied the GPT HTML chat-history example."
                                )
                            },
                            onRevealGPTPDFChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-pdf-example.pdf",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT PDF chat-history example."
                                )
                            },
                            onCopyGPTPDFChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-pdf-example.pdf",
                                    successStatus: "Copied the GPT PDF chat-history example."
                                )
                            },
                            onRevealGPTWebArchiveChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-webarchive-example.webarchive",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT webarchive chat-history example."
                                )
                            },
                            onCopyGPTWebArchiveChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-webarchive-example.webarchive",
                                    successStatus: "Copied the GPT webarchive chat-history example."
                                )
                            },
                            onRevealGPTEmbeddedPlusFenceChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-embedded-plus-fence-example.md",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT embedded-plus-fence chat-history example."
                                )
                            },
                            onCopyGPTEmbeddedPlusFenceChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-embedded-plus-fence-example.md",
                                    successStatus: "Copied the GPT embedded-plus-fence chat-history example."
                                )
                            },
                            onRevealGPTFencePlusEmbeddedChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-fence-plus-embedded-example.md",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT fence-plus-embedded chat-history example."
                                )
                            },
                            onCopyGPTFencePlusEmbeddedChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-fence-plus-embedded-example.md",
                                    successStatus: "Copied the GPT fence-plus-embedded chat-history example."
                                )
                            },
                            onRevealGPTMultiEmbeddedChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-multi-embedded-example.txt",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT multi-embedded chat-history example."
                                )
                            },
                            onCopyGPTMultiEmbeddedChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-multi-embedded-example.txt",
                                    successStatus: "Copied the GPT multi-embedded chat-history example."
                                )
                            },
                            onRevealGPTMultiFenceChatHistoryExample: {
                                openSupportFile(
                                    named: "chat-history-gpt-multi-fence-example.md",
                                    openAction: { url in
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                        return true
                                    },
                                    successStatus: "Revealed the GPT multi-fence chat-history example."
                                )
                            },
                            onCopyGPTMultiFenceChatHistoryExample: {
                                copySupportTextFile(
                                    named: "chat-history-gpt-multi-fence-example.md",
                                    successStatus: "Copied the GPT multi-fence chat-history example."
                                )
                            },
                            onCapture: {
                                captureSeed = nil
                                showingCaptureSheet = true
                            },
                            onCaptureClipboard: {
                                captureSeed = clipboardCaptureSeed()
                                if captureSeed != nil {
                                    showingCaptureSheet = true
                                }
                            },
                            onImportClipboardJSON: {
                                importJSONFromClipboard()
                            },
                            onImport: { showingImporter = true },
                            onExport: { showingExporter = true },
                            onSave: {
                                try? store.save()
                                store.refreshBackupInfo()
                            },
                            onReload: {
                                store.reloadFromDisk()
                            }
                        )
                    }
                    Spacer()
                }
                .padding(28)

                if let bubble = store.selectedBubble {
                    HStack {
                        Spacer()
                        BubbleDetailPanel(bubble: bubble)
                            .frame(width: min(max(proxy.size.width * 0.32, 360), 420))
                            .padding(.trailing, 28)
                            .padding(.vertical, 28)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: store.selectedId)
    }

    private var searchModeActive: Bool {
        !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            handleImportedURLs(urls)
        } catch {
            store.statusText = "Import failed: \(error.localizedDescription)"
        }
    }

    private func handleDroppedURLs(_ urls: [URL]) {
        let webURLs = urls.filter { $0.isWebURL }
        let fileURLs = urls.filter { !$0.isWebURL }

        guard !webURLs.isEmpty else {
            handleDroppedFileURLs(fileURLs)
            return
        }

        guard fileURLs.isEmpty else {
            store.statusText = "Drop webpage links separately from files."
            return
        }

        if webURLs.count == 1, let webURL = webURLs.first {
            guard let seed = captureSeed(from: webURL.absoluteString, sourceApp: "Dropped Web Link", emptyStatus: "Dropped link was empty.") else {
                return
            }
            captureSeed = seed
            showingCaptureSheet = true
            return
        }

        let capturedLinks = webURLs.map(\.absoluteString).joined(separator: "\n")
        captureSeed = CaptureImportSeed(
            sourceType: .textSelection,
            sourceTitle: "Dropped web links",
            sourceURLString: "",
            suggestedTitle: "Web links",
            capturedText: capturedLinks,
            sourceApp: "Dropped Web Links"
        )
        store.statusText = "Dropped Web Links capture recognized \(webURLs.count) webpage links."
        showingCaptureSheet = true
    }

    private func handleDroppedFileURLs(_ urls: [URL]) {
        let webLocationFileURLs = urls.filter { $0.isWebLocationFile }
        let textFileURLs = urls.filter { $0.isTextCaptureFile }
        let imageFileURLs = urls.filter { $0.isImageCaptureFile }
        let audioFileURLs = urls.filter { $0.isAudioCaptureFile }
        let videoFileURLs = urls.filter { $0.isVideoCaptureFile }
        let jsonFileURLs = urls.filter { $0.pathExtension.caseInsensitiveCompare("json") == .orderedSame }

        if !webLocationFileURLs.isEmpty {
            guard textFileURLs.isEmpty, imageFileURLs.isEmpty, audioFileURLs.isEmpty, videoFileURLs.isEmpty, jsonFileURLs.isEmpty else {
                store.statusText = "Drop saved web links separately from text, media, or JSON files."
                return
            }

            let webURLs = webLocationFileURLs.compactMap { webLocationURL(from: $0) }
            guard !webURLs.isEmpty else {
                store.statusText = "No readable web links found in dropped files."
                return
            }

            handleDroppedURLs(webURLs)
            return
        }

        if !imageFileURLs.isEmpty {
            guard textFileURLs.isEmpty, audioFileURLs.isEmpty, videoFileURLs.isEmpty, jsonFileURLs.isEmpty else {
                store.statusText = "Drop image files separately from text, audio, video, or JSON files."
                return
            }

            let capturedParts = imageFileURLs.map { url in
                """
                Source file: \(url.lastPathComponent)

                Image file captured for BubblePath.

                Add notes here about what this image means, where it came from, and how it connects to the rest of your thought web.
                """
            }
            let sourceTitle = imageFileURLs.count == 1
                ? imageFileURLs[0].lastPathComponent
                : "\(imageFileURLs.count) dropped image files"
            captureSeed = CaptureImportSeed(
                sourceType: .imageFile,
                sourceTitle: sourceTitle,
                sourceURLString: sourceURLString(forSingleFileIn: imageFileURLs),
                suggestedTitle: sourceTitle,
                capturedText: capturedParts.joined(separator: "\n\n---\n\n"),
                sourceApp: imageFileURLs.count == 1 ? "Dropped Image File" : "Dropped Image Files"
            )
            store.statusText = "\(imageFileURLs.count == 1 ? "Dropped Image File" : "Dropped Image Files") capture recognized \(imageFileURLs.count) image file\(imageFileURLs.count == 1 ? "" : "s")."
            showingCaptureSheet = true
            return
        }

        if !audioFileURLs.isEmpty {
            guard textFileURLs.isEmpty, videoFileURLs.isEmpty, jsonFileURLs.isEmpty else {
                store.statusText = "Drop audio files separately from text, video, or JSON files."
                return
            }

            let capturedParts = audioFileURLs.map { url in
                """
                Source file: \(url.lastPathComponent)

                Audio file captured for BubblePath.

                Add notes here about what this sound, voice note, lecture, or recording means, where it came from, and how it connects to the rest of your thought web.
                """
            }
            let sourceTitle = audioFileURLs.count == 1
                ? audioFileURLs[0].lastPathComponent
                : "\(audioFileURLs.count) dropped audio files"
            captureSeed = CaptureImportSeed(
                sourceType: .audioFile,
                sourceTitle: sourceTitle,
                sourceURLString: sourceURLString(forSingleFileIn: audioFileURLs),
                suggestedTitle: sourceTitle,
                capturedText: capturedParts.joined(separator: "\n\n---\n\n"),
                sourceApp: audioFileURLs.count == 1 ? "Dropped Audio File" : "Dropped Audio Files"
            )
            store.statusText = "\(audioFileURLs.count == 1 ? "Dropped Audio File" : "Dropped Audio Files") capture recognized \(audioFileURLs.count) audio file\(audioFileURLs.count == 1 ? "" : "s")."
            showingCaptureSheet = true
            return
        }

        if !videoFileURLs.isEmpty {
            guard textFileURLs.isEmpty, jsonFileURLs.isEmpty else {
                store.statusText = "Drop video files separately from text or JSON files."
                return
            }

            let capturedParts = videoFileURLs.map { url in
                """
                Source file: \(url.lastPathComponent)

                Video file captured for BubblePath.

                Add notes here about what this video means, where it came from, and how it connects to the rest of your thought web.
                """
            }
            let sourceTitle = videoFileURLs.count == 1
                ? videoFileURLs[0].lastPathComponent
                : "\(videoFileURLs.count) dropped video files"
            captureSeed = CaptureImportSeed(
                sourceType: .videoFile,
                sourceTitle: sourceTitle,
                sourceURLString: sourceURLString(forSingleFileIn: videoFileURLs),
                suggestedTitle: sourceTitle,
                capturedText: capturedParts.joined(separator: "\n\n---\n\n"),
                sourceApp: videoFileURLs.count == 1 ? "Dropped Video File" : "Dropped Video Files"
            )
            store.statusText = "\(videoFileURLs.count == 1 ? "Dropped Video File" : "Dropped Video Files") capture recognized \(videoFileURLs.count) video file\(videoFileURLs.count == 1 ? "" : "s")."
            showingCaptureSheet = true
            return
        }

        guard !textFileURLs.isEmpty else {
            handleImportedURLs(urls)
            return
        }

        let importableTextResponseURLs = textFileURLs.filter { looksLikeSupportedImportPayload(at: $0) }
        let plainTextCaptureURLs = textFileURLs.filter { !importableTextResponseURLs.contains($0) }

        if !importableTextResponseURLs.isEmpty {
            guard plainTextCaptureURLs.isEmpty else {
                store.statusText = "Drop saved GPT response files separately from plain text capture files."
                return
            }

            handleImportedURLs(jsonFileURLs + importableTextResponseURLs)
            return
        }

        let failedGPTResponseURLs = plainTextCaptureURLs.filter { looksLikeFailedGPTResponseAttempt(at: $0) }
        let plainTextCaptureOnlyURLs = plainTextCaptureURLs.filter { !failedGPTResponseURLs.contains($0) }

        if !failedGPTResponseURLs.isEmpty {
            guard plainTextCaptureOnlyURLs.isEmpty else {
                store.statusText = "Drop saved GPT response files separately from plain text capture files."
                return
            }

            if failedGPTResponseURLs.count == 1, let failedFile = failedGPTResponseURLs.first {
                store.statusText = "Import failed: no BubblePath JSON found in \(friendlyImportSourceLabel(for: failedFile.lastPathComponent)). If this is a GPT response, try the GPT fenced or embedded example formats, or use the shape guide."
            } else {
                store.statusText = "Import failed: no BubblePath JSON found in \(failedGPTResponseURLs.count) GPT response files. Try the GPT fenced or embedded example formats, or use the shape guide."
            }
            return
        }

        guard jsonFileURLs.isEmpty else {
            store.statusText = "Drop text files separately from JSON files."
            return
        }

        var capturedParts: [String] = []
        var skippedCount = 0

        for url in plainTextCaptureOnlyURLs {
            do {
                let text = try readableText(from: url)
                guard !text.isEmpty else {
                    skippedCount += 1
                    continue
                }
                capturedParts.append("Source file: \(url.lastPathComponent)\n\n\(text)")
            } catch {
                skippedCount += 1
            }
        }

        guard !capturedParts.isEmpty else {
            store.statusText = "No readable text found in dropped files.\(skippedImportSuffix(skippedCount))"
            return
        }

        let sourceTitle = plainTextCaptureOnlyURLs.count == 1
            ? plainTextCaptureOnlyURLs[0].lastPathComponent
            : "\(plainTextCaptureOnlyURLs.count) dropped text files"
        captureSeed = CaptureImportSeed(
            sourceType: .textSelection,
            sourceTitle: sourceTitle,
            sourceURLString: capturedParts.count == 1 ? sourceURLString(forSingleFileIn: plainTextCaptureOnlyURLs) : "",
            suggestedTitle: sourceTitle,
            capturedText: capturedParts.joined(separator: "\n\n---\n\n"),
            sourceApp: capturedParts.count == 1 ? "Dropped Text File" : "Dropped Text Files"
        )
        let sourceApp = capturedParts.count == 1 ? "Dropped Text File" : "Dropped Text Files"
        store.statusText = "\(sourceApp) capture recognized \(capturedParts.count) text file\(capturedParts.count == 1 ? "" : "s").\(skippedImportSuffix(skippedCount))"
        showingCaptureSheet = true
    }

    private func sourceURLString(forSingleFileIn urls: [URL]) -> String {
        urls.count == 1 ? urls[0].absoluteString : ""
    }

    private func readableText(from url: URL) throws -> String {
        if let text = readableTextViaTextUtil(from: url), !text.isEmpty {
            return text
        }

        if url.isWebArchiveCaptureFile {
            let data = try Data(contentsOf: url)
            if let webArchive = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let mainResource = webArchive["WebMainResource"] as? [String: Any],
               let resourceData = mainResource["WebResourceData"] as? Data {
                return try NSAttributedString(
                    data: resourceData,
                    options: [.documentType: NSAttributedString.DocumentType.html],
                    documentAttributes: nil
                )
                .string
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }

        if url.pathExtension.caseInsensitiveCompare("rtf") == .orderedSame {
            return try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            .string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if url.isHTMLCaptureFile {
            let data = try Data(contentsOf: url)
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            )
            .string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if url.isPDFCaptureFile {
            guard let document = PDFDocument(url: url) else { return "" }
            return (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readableTextViaTextUtil(from url: URL) -> String? {
        let supportedExtensions = ["rtf", "doc", "docx", "odt"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "txt", "-stdout", url.path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func webLocationURL(from url: URL) -> URL? {
        if let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let urlString = dict["URL"] as? String,
           let webURL = URL(string: urlString),
           webURL.isWebURL {
            return webURL
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let urlString = text
            .components(separatedBy: .newlines)
            .first { $0.lowercased().hasPrefix("url=") }?
            .dropFirst(4)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let urlString,
              let webURL = URL(string: urlString),
              webURL.isWebURL
        else {
            return nil
        }

        return webURL
    }

    private func handleImportedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else {
            store.statusText = "Import canceled."
            return
        }

        let decoder = JSONDecoder.bubblePathDecoder
        var capturePayloads: [BubbleCapturePayload] = []
        var capturePayloadSourceFiles: [String] = []
        var documentImport: (document: BubblePathDocument, url: URL)?
        var skippedFiles: [String] = []
        var emptyCaptureBatchFiles: [String] = []
        var emptyChatHistoryBatchFiles: [String] = []
        var malformedCaptureBatchFiles: [String] = []
        var malformedChatHistoryBatchFiles: [String] = []
        var invalidChatHistoryEntryBatchFiles: [String] = []
        var looseChatHistorySourceFiles: [String] = []
        var looseChatHistorySourceKindsByFile: [String: String] = [:]
        var extractedImportSourceFiles: [String] = []
        var extractedImportKindsByFile: [String: String] = [:]
        var extractedImportSkippedNoiseByFile: [String: Bool] = [:]

        for url in urls {
            guard url.pathExtension.caseInsensitiveCompare("json") == .orderedSame || url.isTextCaptureFile else {
                skippedFiles.append(url.lastPathComponent)
                continue
            }

            let normalizedImport: (data: Data, extractedKind: String?, skippedEarlierJSONNoise: Bool)
            do {
                normalizedImport = try normalizedImportJSONData(from: url)
            } catch {
                skippedFiles.append(url.lastPathComponent)
                continue
            }
            let data = normalizedImport.data

            if let extractedKind = normalizedImport.extractedKind {
                extractedImportSourceFiles.append(url.lastPathComponent)
                extractedImportKindsByFile[url.lastPathComponent] = extractedKind
                extractedImportSkippedNoiseByFile[url.lastPathComponent] = normalizedImport.skippedEarlierJSONNoise
            }

            if let envelope = try? decoder.decode(BubbleCaptureImportEnvelope.self, from: data) {
                let resolvedCaptures = envelope.resolvedCaptures
                if resolvedCaptures.isEmpty {
                    emptyCaptureBatchFiles.append(url.lastPathComponent)
                } else {
                    capturePayloads.append(contentsOf: resolvedCaptures)
                    capturePayloadSourceFiles.append(url.lastPathComponent)
                }
                continue
            }

            if let chatEnvelope = try? decoder.decode(BubbleChatImportEnvelope.self, from: data) {
                let resolvedCaptures = chatEnvelope.resolvedCaptures
                if resolvedCaptures.isEmpty {
                    emptyChatHistoryBatchFiles.append(url.lastPathComponent)
                } else {
                    capturePayloads.append(contentsOf: resolvedCaptures)
                    capturePayloadSourceFiles.append(url.lastPathComponent)
                }
                continue
            }

            if let looseChatEnvelope = try? decoder.decode(BubbleLooseChatImportEnvelope.self, from: data) {
                let resolvedCaptures = looseChatEnvelope.resolvedCaptures
                if resolvedCaptures.isEmpty {
                    emptyChatHistoryBatchFiles.append(url.lastPathComponent)
                } else {
                    capturePayloads.append(contentsOf: resolvedCaptures)
                    capturePayloadSourceFiles.append(url.lastPathComponent)
                    looseChatHistorySourceFiles.append(url.lastPathComponent)
                    looseChatHistorySourceKindsByFile[url.lastPathComponent] = "object-with-chats"
                }
                continue
            }

            if let chatEntries = try? decoder.decode([BubbleChatImportEntry].self, from: data) {
                if chatEntries.isEmpty {
                    emptyChatHistoryBatchFiles.append(url.lastPathComponent)
                } else {
                    let resolvedCaptures = BubbleLooseChatImportEnvelope(
                        sourceApp: nil,
                        sourceChatTitle: nil,
                        sourceChatID: nil,
                        sourceURL: nil,
                        chats: chatEntries
                    )
                    .resolvedCaptures
                    capturePayloads.append(contentsOf: resolvedCaptures)
                    capturePayloadSourceFiles.append(url.lastPathComponent)
                    looseChatHistorySourceFiles.append(url.lastPathComponent)
                    looseChatHistorySourceKindsByFile[url.lastPathComponent] = "root-array"
                }
                continue
            }

            if let payloads = try? decoder.decode([BubbleCapturePayload].self, from: data) {
                if payloads.isEmpty {
                    emptyCaptureBatchFiles.append(url.lastPathComponent)
                } else {
                    capturePayloads.append(contentsOf: payloads)
                    capturePayloadSourceFiles.append(url.lastPathComponent)
                }
                continue
            }

            if let payload = try? decoder.decode(BubbleCapturePayload.self, from: data) {
                capturePayloads.append(payload)
                capturePayloadSourceFiles.append(url.lastPathComponent)
                continue
            }

            if let chatEntry = try? decoder.decode(BubbleChatImportEntry.self, from: data) {
                let resolvedCapture = BubbleLooseChatImportEnvelope(
                    sourceApp: nil,
                    sourceChatTitle: nil,
                    sourceChatID: nil,
                    sourceURL: nil,
                    chats: [chatEntry]
                )
                .resolvedCaptures
                capturePayloads.append(contentsOf: resolvedCapture)
                capturePayloadSourceFiles.append(url.lastPathComponent)
                looseChatHistorySourceFiles.append(url.lastPathComponent)
                looseChatHistorySourceKindsByFile[url.lastPathComponent] = "single-entry"
                continue
            }

            if let document = try? decoder.decode(BubblePathDocument.self, from: data) {
                documentImport = (document, url)
                continue
            }

            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let kind = object["kind"] as? String {
                switch kind {
                case "capture-batch":
                    malformedCaptureBatchFiles.append(url.lastPathComponent)
                    continue
                case "chat-history-batch":
                    if chatHistoryBatchHasInvalidEntries(object) {
                        invalidChatHistoryEntryBatchFiles.append(url.lastPathComponent)
                    } else {
                        malformedChatHistoryBatchFiles.append(url.lastPathComponent)
                    }
                    continue
                default:
                    break
                }
            }

            skippedFiles.append(url.lastPathComponent)
        }

        if !capturePayloads.isEmpty {
            guard documentImport == nil else {
                store.statusText = "Choose capture JSON separately from full vault imports."
                return
            }

            if capturePayloads.count == 1, let payload = capturePayloads.first {
                store.importCapture(payload)
            } else {
                store.importCaptures(capturePayloads)
            }

            let uniqueImportFiles = Array(Set(capturePayloadSourceFiles)).sorted()
            if uniqueImportFiles.count == 1, let importedFile = uniqueImportFiles.first {
                store.statusText += " Imported from \(friendlyImportSourceLabel(for: importedFile))."
            }

            store.statusText += looseChatHistoryImportSuffix(
                sourceFiles: looseChatHistorySourceFiles,
                sourceKindsByFile: looseChatHistorySourceKindsByFile
            )
            store.statusText += extractedImportSuffix(
                sourceFiles: extractedImportSourceFiles,
                sourceKindsByFile: extractedImportKindsByFile,
                skippedNoiseByFile: extractedImportSkippedNoiseByFile
            )

            store.statusText += importOutcomeSuffix(
                skippedFiles: skippedFiles,
                emptyCaptureBatchFiles: emptyCaptureBatchFiles,
                emptyChatHistoryBatchFiles: emptyChatHistoryBatchFiles,
                malformedCaptureBatchFiles: malformedCaptureBatchFiles,
                malformedChatHistoryBatchFiles: malformedChatHistoryBatchFiles,
                invalidChatHistoryEntryBatchFiles: invalidChatHistoryEntryBatchFiles
            )
            return
        }

        if let documentImport, urls.count == 1 {
            store.importDocument(documentImport.document, from: documentImport.url)
            return
        }

        if !emptyChatHistoryBatchFiles.isEmpty, documentImport == nil, skippedFiles.isEmpty, emptyCaptureBatchFiles.isEmpty {
            store.statusText = importFailureMessage(
                singular: "Import failed: the chat-history batch was empty.",
                plural: "Import failed: \(emptyChatHistoryBatchFiles.count) chat-history batches were empty.",
                files: emptyChatHistoryBatchFiles
            )
            return
        }

        if !emptyCaptureBatchFiles.isEmpty, documentImport == nil, skippedFiles.isEmpty, emptyChatHistoryBatchFiles.isEmpty {
            store.statusText = importFailureMessage(
                singular: "Import failed: the capture batch was empty.",
                plural: "Import failed: \(emptyCaptureBatchFiles.count) capture batches were empty.",
                files: emptyCaptureBatchFiles
            )
            return
        }

        if !malformedChatHistoryBatchFiles.isEmpty, documentImport == nil, skippedFiles.isEmpty, emptyCaptureBatchFiles.isEmpty, emptyChatHistoryBatchFiles.isEmpty {
            store.statusText = importFailureMessage(
                singular: "Import failed: the chat-history batch JSON was malformed.",
                plural: "Import failed: \(malformedChatHistoryBatchFiles.count) chat-history batch JSON files were malformed.",
                files: malformedChatHistoryBatchFiles
            )
            return
        }

        if !invalidChatHistoryEntryBatchFiles.isEmpty,
           documentImport == nil,
           skippedFiles.isEmpty,
           emptyCaptureBatchFiles.isEmpty,
           emptyChatHistoryBatchFiles.isEmpty,
           malformedChatHistoryBatchFiles.isEmpty {
            store.statusText = importFailureMessage(
                singular: "Import failed: the chat-history batch had invalid entries.",
                plural: "Import failed: \(invalidChatHistoryEntryBatchFiles.count) chat-history batches had invalid entries.",
                files: invalidChatHistoryEntryBatchFiles
            )
            return
        }

        if !malformedCaptureBatchFiles.isEmpty, documentImport == nil, skippedFiles.isEmpty, emptyCaptureBatchFiles.isEmpty, emptyChatHistoryBatchFiles.isEmpty, malformedChatHistoryBatchFiles.isEmpty {
            store.statusText = importFailureMessage(
                singular: "Import failed: the capture batch JSON was malformed.",
                plural: "Import failed: \(malformedCaptureBatchFiles.count) capture batch JSON files were malformed.",
                files: malformedCaptureBatchFiles
            )
            return
        }

        if documentImport != nil {
            store.statusText = "Import one full BubblePath vault at a time.\(importOutcomeSuffix(skippedFiles: skippedFiles, emptyCaptureBatchFiles: emptyCaptureBatchFiles, emptyChatHistoryBatchFiles: emptyChatHistoryBatchFiles, malformedCaptureBatchFiles: malformedCaptureBatchFiles, malformedChatHistoryBatchFiles: malformedChatHistoryBatchFiles, invalidChatHistoryEntryBatchFiles: invalidChatHistoryEntryBatchFiles))"
        } else {
            if skippedFiles.count == 1,
               let skippedFile = skippedFiles.first,
               emptyCaptureBatchFiles.isEmpty,
               emptyChatHistoryBatchFiles.isEmpty,
               malformedCaptureBatchFiles.isEmpty,
               malformedChatHistoryBatchFiles.isEmpty,
               invalidChatHistoryEntryBatchFiles.isEmpty {
                if isGPTResponseStyleFileName(skippedFile) {
                    store.statusText = "Import failed: no BubblePath JSON found in \(friendlyImportSourceLabel(for: skippedFile)). If this is a GPT response, try the GPT fenced or embedded example formats, or use the shape guide."
                } else if skippedFile.lowercased().hasSuffix(".json") {
                    store.statusText = "Import failed: no BubblePath import data was found in \(friendlyImportSourceLabel(for: skippedFile))."
                } else {
                    store.statusText = "Import failed: BubblePath could not import \(friendlyImportSourceLabel(for: skippedFile))."
                }
            } else {
                store.statusText = "Import failed: no BubblePath JSON found.\(importOutcomeSuffix(skippedFiles: skippedFiles, emptyCaptureBatchFiles: emptyCaptureBatchFiles, emptyChatHistoryBatchFiles: emptyChatHistoryBatchFiles, malformedCaptureBatchFiles: malformedCaptureBatchFiles, malformedChatHistoryBatchFiles: malformedChatHistoryBatchFiles, invalidChatHistoryEntryBatchFiles: invalidChatHistoryEntryBatchFiles))"
            }
        }
    }

    private func looseChatHistoryImportSuffix(
        sourceFiles: [String],
        sourceKindsByFile: [String: String]
    ) -> String {
        let uniqueSourceFiles = Array(Set(sourceFiles)).sorted()
        guard !uniqueSourceFiles.isEmpty else { return "" }

        if uniqueSourceFiles.count == 1, let sourceFile = uniqueSourceFiles.first {
            if let sourceKind = sourceKindsByFile[sourceFile] {
                return " Normalized \(sourceKind) chat-history JSON from \(friendlyImportSourceLabel(for: sourceFile))."
            }
            return " Normalized loose chat-history JSON from \(friendlyImportSourceLabel(for: sourceFile))."
        }

        let uniqueKinds = Array(
            Set(
                uniqueSourceFiles.compactMap { sourceKindsByFile[$0] }
            )
        )
        .sorted()

        if uniqueKinds.count == 1, let sourceKind = uniqueKinds.first {
            return " Normalized \(sourceKind) chat-history JSON from \(uniqueSourceFiles.count) files."
        }

        if !uniqueKinds.isEmpty {
            return " Normalized mixed loose chat-history JSON (\(uniqueKinds.joined(separator: ", "))) from \(uniqueSourceFiles.count) files."
        }

        return " Normalized loose chat-history JSON from \(uniqueSourceFiles.count) files."
    }

    private func skippedImportSuffix(_ skippedCount: Int) -> String {
        guard skippedCount > 0 else { return "" }
        return " Skipped \(skippedCount) unsupported file\(skippedCount == 1 ? "" : "s")."
    }

    private func importOutcomeSuffix(
        skippedFiles: [String],
        emptyCaptureBatchFiles: [String],
        emptyChatHistoryBatchFiles: [String],
        malformedCaptureBatchFiles: [String],
        malformedChatHistoryBatchFiles: [String],
        invalidChatHistoryEntryBatchFiles: [String] = []
    ) -> String {
        var parts: [String] = []

        if !skippedFiles.isEmpty {
            parts.append(importOutcomeLabel(
                singular: "Skipped unsupported file",
                plural: "Skipped \(skippedFiles.count) unsupported files",
                files: skippedFiles
            ))
        }
        if !emptyCaptureBatchFiles.isEmpty {
            parts.append(importOutcomeLabel(
                singular: "empty capture batch",
                plural: "\(emptyCaptureBatchFiles.count) empty capture batches",
                files: emptyCaptureBatchFiles
            ))
        }
        if !emptyChatHistoryBatchFiles.isEmpty {
            parts.append(importOutcomeLabel(
                singular: "empty chat-history batch",
                plural: "\(emptyChatHistoryBatchFiles.count) empty chat-history batches",
                files: emptyChatHistoryBatchFiles
            ))
        }
        if !malformedCaptureBatchFiles.isEmpty {
            parts.append(importOutcomeLabel(
                singular: "malformed capture batch",
                plural: "\(malformedCaptureBatchFiles.count) malformed capture batches",
                files: malformedCaptureBatchFiles
            ))
        }
        if !malformedChatHistoryBatchFiles.isEmpty {
            parts.append(importOutcomeLabel(
                singular: "malformed chat-history batch",
                plural: "\(malformedChatHistoryBatchFiles.count) malformed chat-history batches",
                files: malformedChatHistoryBatchFiles
            ))
        }
        if !invalidChatHistoryEntryBatchFiles.isEmpty {
            parts.append(importOutcomeLabel(
                singular: "chat-history batch with invalid entries",
                plural: "\(invalidChatHistoryEntryBatchFiles.count) chat-history batches with invalid entries",
                files: invalidChatHistoryEntryBatchFiles
            ))
        }

        guard !parts.isEmpty else { return "" }
        return " " + parts.joined(separator: ". ") + "."
    }

    private func importOutcomeLabel(singular: String, plural: String, files: [String]) -> String {
        guard files.count == 1, let fileName = files.first else { return plural }
        return "\(singular) (\(friendlyImportSourceLabel(for: fileName)))"
    }

    private func importFailureMessage(singular: String, plural: String, files: [String]) -> String {
        guard !files.isEmpty else { return singular }
        guard files.count == 1, let fileName = files.first else { return plural }
        return "\(singular) (\(friendlyImportSourceLabel(for: fileName)))"
    }

    private func friendlyImportSourceLabel(for fileName: String) -> String {
        let lowercasedName = fileName.lowercased()
        if fileName.hasPrefix("bubblepath-clipboard-import-"),
           lowercasedName.hasSuffix(".json") {
            return "clipboard JSON"
        }

        if lowercasedName.hasSuffix(".json") {
            if lowercasedName.contains("chat-history") {
                return "saved chat-history JSON file \(fileName)"
            }

            if lowercasedName.contains("capture-batch") || lowercasedName.contains("capture") {
                return "saved capture JSON file \(fileName)"
            }

            if lowercasedName.contains("bubblepath-data")
                || lowercasedName.contains("bubblepath-vault")
                || lowercasedName.contains("bubblepath-") {
                return "saved BubblePath vault JSON file \(fileName)"
            }

            return "saved import JSON file \(fileName)"
        }

        if lowercasedName.hasSuffix(".txt")
            || lowercasedName.hasSuffix(".text") {
            return "saved text response \(fileName)"
        }

        if lowercasedName.hasSuffix(".md")
            || lowercasedName.hasSuffix(".markdown") {
            return "saved markdown response \(fileName)"
        }

        if lowercasedName.hasSuffix(".doc") {
            return "saved DOC response \(fileName)"
        }

        if lowercasedName.hasSuffix(".docx") {
            return "saved DOCX response \(fileName)"
        }

        if lowercasedName.hasSuffix(".odt") {
            return "saved ODT response \(fileName)"
        }

        if lowercasedName.hasSuffix(".rtf") {
            return "saved RTF response \(fileName)"
        }

        if lowercasedName.hasSuffix(".html")
            || lowercasedName.hasSuffix(".htm") {
            return "saved HTML response \(fileName)"
        }

        if lowercasedName.hasSuffix(".webarchive") {
            return "saved webarchive response \(fileName)"
        }

        if lowercasedName.hasSuffix(".pdf") {
            return "saved PDF response \(fileName)"
        }

        return fileName
    }

    private func isGPTResponseStyleFileName(_ fileName: String) -> Bool {
        let lowercasedName = fileName.lowercased()
        return lowercasedName.hasSuffix(".txt")
            || lowercasedName.hasSuffix(".text")
            || lowercasedName.hasSuffix(".md")
            || lowercasedName.hasSuffix(".markdown")
            || lowercasedName.hasSuffix(".doc")
            || lowercasedName.hasSuffix(".docx")
            || lowercasedName.hasSuffix(".odt")
            || lowercasedName.hasSuffix(".rtf")
            || lowercasedName.hasSuffix(".html")
            || lowercasedName.hasSuffix(".htm")
            || lowercasedName.hasSuffix(".pdf")
            || lowercasedName.hasSuffix(".webarchive")
    }

    private func chatHistoryBatchHasInvalidEntries(_ object: [String: Any]) -> Bool {
        guard let chats = object["chats"] as? [[String: Any]], !chats.isEmpty else { return false }
        let allowedBubbleTypes: Set<String> = ["thought", "question", "decision", "seed", "file", "chat"]

        for chat in chats {
            let bubbleTitle = (chat["bubbleTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let excerpt = (chat["excerpt"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if bubbleTitle.isEmpty || excerpt.isEmpty {
                return true
            }

            if let bubbleType = (chat["bubbleType"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !bubbleType.isEmpty,
               !allowedBubbleTypes.contains(bubbleType) {
                return true
            }
        }

        return false
    }

    private func handleExport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            store.statusText = "Exported BubblePath JSON to \(url.lastPathComponent)."
        } catch {
            store.statusText = "Export failed: \(error.localizedDescription)"
        }
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func openSupportFile(
        named fileName: String,
        openAction: (URL) -> Bool,
        successStatus: String
    ) {
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            store.statusText = "Could not find \(fileName)."
            return
        }

        guard openAction(fileURL) else {
            store.statusText = "Could not open \(fileName)."
            return
        }

        store.statusText = successStatus
    }

    private func openSupportFiles(
        named fileNames: [String],
        openAction: ([URL]) -> Bool,
        successStatus: String
    ) {
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileURLs = fileNames.map { baseURL.appendingPathComponent($0) }

        let missingFiles = fileNames.enumerated()
            .compactMap { index, fileName in
                FileManager.default.fileExists(atPath: fileURLs[index].path) ? nil : fileName
            }
        guard missingFiles.isEmpty else {
            store.statusText = "Could not find \(missingFiles.joined(separator: ", "))."
            return
        }

        guard openAction(fileURLs) else {
            store.statusText = "Could not reveal the requested support files."
            return
        }

        store.statusText = successStatus
    }

    private func copySupportTextFile(named fileName: String, successStatus: String) {
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            store.statusText = "Could not find \(fileName)."
            return
        }

        let contents: String
        if let directContents = try? String(contentsOf: fileURL, encoding: .utf8) {
            contents = directContents
        } else if let extractedContents = try? readableText(from: fileURL),
                  !extractedContents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contents = extractedContents
        } else {
            store.statusText = "Could not read \(fileName)."
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(contents, forType: .string) else {
            store.statusText = "Could not copy \(fileName)."
            return
        }

        store.statusText = successStatus
    }

    private func clipboardCaptureSeed() -> CaptureImportSeed? {
        guard let rawString = NSPasteboard.general.string(forType: .string) else {
            store.statusText = "Clipboard is empty."
            return nil
        }

        return captureSeed(from: rawString, sourceApp: "Clipboard", emptyStatus: "Clipboard is empty.")
    }

    private func importJSONFromClipboard() {
        guard let rawString = NSPasteboard.general.string(forType: .string) else {
            store.statusText = "Clipboard import failed: no text found on the clipboard."
            return
        }

        let normalization = normalizedClipboardJSON(rawString)
        let trimmed = normalization.json
        guard !trimmed.isEmpty else {
            store.statusText = "Clipboard import failed: clipboard text was empty."
            return
        }

        guard let data = trimmed.data(using: .utf8) else {
            store.statusText = "Clipboard import failed: clipboard text could not be read as UTF-8."
            return
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            store.statusText = "Clipboard import failed: clipboard text was not valid JSON."
            return
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bubblepath-clipboard-import-\(UUID().uuidString).json")

        do {
            try trimmed.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            store.statusText = "Clipboard import failed: could not write a temporary JSON file."
            return
        }

        handleImportedURLs([tempURL])
        if store.statusText.hasPrefix("Import failed: no BubblePath JSON found.") {
            store.statusText = "Clipboard import failed: the clipboard JSON was not a BubblePath batch, capture batch, full BubblePath vault, or directly supported loose chat-history shape. Try the template, try wrapping it first, or check the shape guide."
        } else if store.statusText.hasPrefix("Import failed:") {
            store.statusText = store.statusText.replacingOccurrences(
                of: "Import failed:",
                with: "Clipboard import failed:",
                options: [.anchored]
            )
        } else if normalization.extractedFencedJSON {
            if normalization.hadSurroundingText {
                store.statusText += " Extracted fenced JSON from a larger clipboard response."
            } else {
                store.statusText += " Stripped outer markdown code fences from clipboard JSON."
            }
            if normalization.skippedEarlierJSONNoise {
                store.statusText += " Skipped earlier unrelated JSON before choosing the BubblePath payload."
            }
        } else if normalization.extractedEmbeddedJSON && normalization.hadSurroundingText {
            store.statusText += " Extracted embedded JSON from a larger clipboard response."
            if normalization.skippedEarlierJSONNoise {
                store.statusText += " Skipped earlier unrelated JSON before choosing the BubblePath payload."
            }
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    private func normalizedClipboardJSON(_ rawString: String) -> (
        json: String,
        extractedFencedJSON: Bool,
        extractedEmbeddedJSON: Bool,
        hadSurroundingText: Bool,
        skippedEarlierJSONNoise: Bool
    ) {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferredJSON = preferredGPTImportJSON(from: trimmed) {
            return (
                preferredJSON.json,
                preferredJSON.kind == "fenced",
                preferredJSON.kind == "embedded",
                preferredJSON.hadSurroundingText,
                preferredJSON.skippedEarlierJSONNoise
            )
        }

        return (trimmed, false, false, false, false)
    }

    private func extractFencedClipboardJSONCandidates(from lines: [String]) -> [String] {
        guard !lines.isEmpty else { return [] }

        var insideFence = false
        var collected: [String] = []
        var candidates: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if !insideFence {
                guard trimmedLine.hasPrefix("```") else { continue }

                let fenceLanguage = String(trimmedLine.dropFirst(3))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                if fenceLanguage.isEmpty || fenceLanguage == "json" {
                    insideFence = true
                    collected.removeAll(keepingCapacity: true)
                }
                continue
            }

            if trimmedLine == "```" {
                let json = collected
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !json.isEmpty {
                    candidates.append(json)
                }
                insideFence = false
                collected.removeAll(keepingCapacity: true)
                continue
            }

            collected.append(line)
        }

        return candidates
    }

    private func preferredFencedImportJSON(from lines: [String]) -> String? {
        let candidates = extractFencedClipboardJSONCandidates(from: lines)
        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            if let candidateData = candidate.data(using: .utf8),
               looksLikeSupportedImportPayload(in: candidateData) {
                return candidate
            }
        }

        return candidates.first
    }

    private func preferredGPTImportJSON(
        from text: String
    ) -> (json: String, kind: String, hadSurroundingText: Bool, skippedEarlierJSONNoise: Bool)? {
        let lines = text.components(separatedBy: .newlines)
        let fencedCandidates = extractFencedClipboardJSONCandidates(from: lines)
        let embeddedCandidates = extractEmbeddedClipboardJSONCandidates(from: text)

        for (index, candidate) in fencedCandidates.enumerated() {
            if let candidateData = candidate.data(using: .utf8),
               looksLikeSupportedImportPayload(in: candidateData) {
                let normalizedFence = "```json\n\(candidate)\n```"
                let hadSurroundingText = text != normalizedFence && text != "```\n\(candidate)\n```"
                return (candidate, "fenced", hadSurroundingText, index > 0 || !embeddedCandidates.isEmpty)
            }
        }

        for (index, candidate) in embeddedCandidates.enumerated() {
            if let candidateData = candidate.data(using: .utf8),
               looksLikeSupportedImportPayload(in: candidateData) {
                return (candidate, "embedded", candidate != text, index > 0 || !fencedCandidates.isEmpty)
            }
        }

        if let fencedJSON = fencedCandidates.first {
            let normalizedFence = "```json\n\(fencedJSON)\n```"
            let hadSurroundingText = text != normalizedFence && text != "```\n\(fencedJSON)\n```"
            return (fencedJSON, "fenced", hadSurroundingText, false)
        }

        if let embeddedJSON = embeddedCandidates.first {
            return (embeddedJSON, "embedded", embeddedJSON != text, false)
        }

        return nil
    }

    private func normalizedImportJSONData(from url: URL) throws -> (data: Data, extractedKind: String?, skippedEarlierJSONNoise: Bool) {
        let data = try Data(contentsOf: url)
        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            return (data, nil, false)
        }

        let text: String
        if url.pathExtension.caseInsensitiveCompare("rtf") == .orderedSame || url.isHTMLCaptureFile || url.isPDFCaptureFile || url.isWebArchiveCaptureFile {
            text = try readableText(from: url)
        } else if let decodedText = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !decodedText.isEmpty {
            text = decodedText
        } else if let extractedText = try? readableText(from: url),
                  !extractedText.isEmpty {
            text = extractedText
        } else {
            return (data, nil, false)
        }

        if let preferredJSON = preferredGPTImportJSON(from: text),
           let preferredData = preferredJSON.json.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: preferredData)) != nil {
            return (preferredData, preferredJSON.kind, preferredJSON.skippedEarlierJSONNoise)
        }

        return (data, nil, false)
    }

    private func looksLikeSupportedImportPayload(at url: URL) -> Bool {
        guard let normalizedImport = try? normalizedImportJSONData(from: url) else {
            return false
        }

        return looksLikeSupportedImportPayload(in: normalizedImport.data)
    }

    private func looksLikeSupportedImportPayload(in data: Data) -> Bool {
        let decoder = JSONDecoder.bubblePathDecoder
        if (try? decoder.decode(BubbleCaptureImportEnvelope.self, from: data)) != nil { return true }
        if (try? decoder.decode(BubbleChatImportEnvelope.self, from: data)) != nil { return true }
        if (try? decoder.decode(BubbleLooseChatImportEnvelope.self, from: data)) != nil { return true }
        if (try? decoder.decode([BubbleChatImportEntry].self, from: data)) != nil { return true }
        if (try? decoder.decode([BubbleCapturePayload].self, from: data)) != nil { return true }
        if (try? decoder.decode(BubbleCapturePayload.self, from: data)) != nil { return true }
        if (try? decoder.decode(BubbleChatImportEntry.self, from: data)) != nil { return true }
        if (try? decoder.decode(BubblePathDocument.self, from: data)) != nil { return true }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let kind = object["kind"] as? String,
           kind == "capture-batch" || kind == "chat-history-batch" {
            return true
        }

        return false
    }

    private func looksLikeFailedGPTResponseAttempt(at url: URL) -> Bool {
        guard url.isTextCaptureFile else {
            return false
        }

        let loweredText: String
        if let data = try? Data(contentsOf: url),
           let decoded = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !decoded.isEmpty {
            loweredText = decoded
        } else if let extractedText = try? readableText(from: url) {
            let extracted = extractedText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !extracted.isEmpty else {
                return false
            }
            loweredText = extracted
        } else {
            return false
        }

        let hasBubblePathSignals =
            loweredText.contains("bubblepath")
            || loweredText.contains("chat-history-batch")
            || loweredText.contains("\"app\": \"bubblepath\"")
            || loweredText.contains("\"kind\": \"chat-history-batch\"")

        let hasEntrySignals =
            loweredText.contains("\"bubbletitle\"")
            || loweredText.contains("\"excerpt\"")
            || loweredText.contains("\"chats\"")
            || loweredText.contains("```json")

        return hasBubblePathSignals && hasEntrySignals
    }

    private func extractedImportSuffix(
        sourceFiles: [String],
        sourceKindsByFile: [String: String],
        skippedNoiseByFile: [String: Bool]
    ) -> String {
        let uniqueSourceFiles = Array(Set(sourceFiles)).sorted()
        guard !uniqueSourceFiles.isEmpty else { return "" }

        if uniqueSourceFiles.count == 1, let sourceFile = uniqueSourceFiles.first {
            switch sourceKindsByFile[sourceFile] {
            case "fenced":
                if skippedNoiseByFile[sourceFile] == true {
                    return " Extracted fenced JSON from \(friendlyImportSourceLabel(for: sourceFile)) after skipping earlier unrelated JSON."
                }
                return " Extracted fenced JSON from \(friendlyImportSourceLabel(for: sourceFile))."
            case "embedded":
                if skippedNoiseByFile[sourceFile] == true {
                    return " Extracted embedded JSON from \(friendlyImportSourceLabel(for: sourceFile)) after skipping earlier unrelated JSON."
                }
                return " Extracted embedded JSON from \(friendlyImportSourceLabel(for: sourceFile))."
            default:
                return ""
            }
        }

        let uniqueKinds = Array(Set(uniqueSourceFiles.compactMap { sourceKindsByFile[$0] })).sorted()
        let skippedNoiseCount = uniqueSourceFiles.filter { skippedNoiseByFile[$0] == true }.count
        if uniqueKinds == ["embedded"] {
            if skippedNoiseCount > 0 {
                return " Extracted embedded JSON from \(uniqueSourceFiles.count) imported files after skipping earlier unrelated JSON in \(skippedNoiseCount) file\(skippedNoiseCount == 1 ? "" : "s")."
            }
            return " Extracted embedded JSON from \(uniqueSourceFiles.count) imported files."
        }
        if uniqueKinds == ["fenced"] {
            if skippedNoiseCount > 0 {
                return " Extracted fenced JSON from \(uniqueSourceFiles.count) imported files after skipping earlier unrelated JSON in \(skippedNoiseCount) file\(skippedNoiseCount == 1 ? "" : "s")."
            }
            return " Extracted fenced JSON from \(uniqueSourceFiles.count) imported files."
        }
        if !uniqueKinds.isEmpty {
            if skippedNoiseCount > 0 {
                return " Extracted mixed GPT-style JSON from \(uniqueSourceFiles.count) imported files after skipping earlier unrelated JSON in \(skippedNoiseCount) file\(skippedNoiseCount == 1 ? "" : "s")."
            }
            return " Extracted mixed GPT-style JSON from \(uniqueSourceFiles.count) imported files."
        }

        return ""
    }

    private func extractEmbeddedClipboardJSONCandidates(from text: String) -> [String] {
        let characters = Array(text)
        var candidates: [String] = []

        for startIndex in characters.indices {
            let opening = characters[startIndex]
            guard opening == "{" || opening == "[" else { continue }

            let closing: Character = opening == "{" ? "}" : "]"
            var depth = 0
            var inString = false
            var isEscaped = false

            for endIndex in startIndex..<characters.count {
                let character = characters[endIndex]

                if inString {
                    if isEscaped {
                        isEscaped = false
                    } else if character == "\\" {
                        isEscaped = true
                    } else if character == "\"" {
                        inString = false
                    }
                    continue
                }

                if character == "\"" {
                    inString = true
                    continue
                }

                if character == opening {
                    depth += 1
                } else if character == closing {
                    depth -= 1
                    if depth == 0 {
                        let candidate = String(characters[startIndex...endIndex])
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if let data = candidate.data(using: .utf8),
                           (try? JSONSerialization.jsonObject(with: data)) != nil {
                            candidates.append(candidate)
                        }

                        break
                    }
                }
            }
        }

        return candidates
    }

    private func extractEmbeddedClipboardJSON(from text: String) -> String? {
        let candidates = extractEmbeddedClipboardJSONCandidates(from: text)
        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            if let candidateData = candidate.data(using: .utf8),
               looksLikeSupportedImportPayload(in: candidateData) {
                return candidate
            }
        }

        return candidates.first
    }

    private func handleDroppedText(_ strings: [String]) {
        let joined = strings.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seed = captureSeed(from: joined, sourceApp: "Dropped Text", emptyStatus: "Dropped text was empty.") else {
            return
        }

        captureSeed = seed
        showingCaptureSheet = true
    }

    private func captureSeed(from rawString: String, sourceApp: String, emptyStatus: String) -> CaptureImportSeed? {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            store.statusText = emptyStatus
            return nil
        }

        let pastedURL = URL(string: trimmed)
        let isWebpage = pastedURL?.scheme?.hasPrefix("http") == true
        let sourceType: BubbleCaptureSourceType = isWebpage ? .webpage : .textSelection
        let host = pastedURL?.host(percentEncoded: false)?.replacingOccurrences(of: "www.", with: "") ?? ""
        let sourceTitle = host
        let suggestedTitle = host.isEmpty ? String(trimmed.prefix(48)) : host
        let preview = String(trimmed.prefix(72))

        if isWebpage {
            let label = host.isEmpty ? "webpage" : host
            store.statusText = "\(sourceApp) capture recognized a webpage from \(label)."
        } else {
            store.statusText = "\(sourceApp) capture recognized text: “\(preview)”"
        }

        return CaptureImportSeed(
            sourceType: sourceType,
            sourceTitle: sourceTitle,
            sourceURLString: pastedURL?.absoluteString ?? "",
            suggestedTitle: suggestedTitle,
            capturedText: trimmed,
            sourceApp: sourceApp
        )
    }
}

private extension URL {
    var isWebURL: Bool {
        scheme?.lowercased().hasPrefix("http") == true
    }

    var isTextCaptureFile: Bool {
        ["txt", "text", "md", "markdown", "rtf", "doc", "docx", "odt", "html", "htm", "pdf", "webarchive"].contains(pathExtension.lowercased())
    }

    var isImageCaptureFile: Bool {
        ["png", "jpg", "jpeg", "gif", "heic", "heif", "tif", "tiff", "bmp", "webp"].contains(pathExtension.lowercased())
    }

    var isAudioCaptureFile: Bool {
        ["mp3", "m4a", "wav", "aiff", "aif", "aac", "flac", "caf"].contains(pathExtension.lowercased())
    }

    var isVideoCaptureFile: Bool {
        ["mov", "mp4", "m4v", "avi", "webm", "mkv"].contains(pathExtension.lowercased())
    }

    var isHTMLCaptureFile: Bool {
        ["html", "htm"].contains(pathExtension.lowercased())
    }

    var isPDFCaptureFile: Bool {
        pathExtension.caseInsensitiveCompare("pdf") == .orderedSame
    }

    var isWebArchiveCaptureFile: Bool {
        pathExtension.caseInsensitiveCompare("webarchive") == .orderedSame
    }

    var isWebLocationFile: Bool {
        ["webloc", "inetloc", "url"].contains(pathExtension.lowercased())
    }
}

private struct HeroPanel: View {
    @EnvironmentObject private var store: BubbleStore
    @EnvironmentObject private var cloudSync: CloudSyncStatusStore
    @FocusState private var searchFieldFocused: Bool

    private let chipColumns = [GridItem(.adaptive(minimum: 72), spacing: 6)]
    private let laneColumns = [GridItem(.adaptive(minimum: 96), spacing: 6)]

    var body: some View {
        let snapshot = store.searchSnapshot()
        let recentBubbles = store.recentBubbles(limit: 5)
        let recentCaptures = store.recentCapturedBubbles(limit: 4)
        let typeSummaries = store.typeSummaries()
        let captureSummaries = store.captureSourceSummaries()
        let hostSummaries = store.captureHostSummaries()
        let appSummaries = store.captureAppSummaries()
        let conversationSummaries = store.sourceConversationSummaries()
        let fileSummaries = store.captureFileSummaries()
        let folderSummaries = store.captureFolderSummaries()
        let recentSearches = store.recentSearches

        VStack(alignment: .leading, spacing: 12) {
            Text("BubblePath")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("A calm space where thoughts can stay fluid for a while.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Search thoughts, drafts, and conversations", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.44), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .focused($searchFieldFocused)
                    .onSubmit {
                        if let firstMatch = (snapshot.direct.first?.bubble ?? snapshot.related.first?.bubble) {
                            HapticsService.shared.perform(.open)
                            store.select(firstMatch.id)
                            searchFieldFocused = false
                        }
                    }

                if snapshot.isExactPhrase {
                    Text("Exact Phrase")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Button {
                    searchFieldFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .keyboardShortcut("f", modifiers: [.command])
                .help("Focus search")

                if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Clear") {
                        store.searchQuery = ""
                        searchFieldFocused = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(searchHintText(for: snapshot))
                .font(.caption2)
                .foregroundStyle(.secondary)

            contentSection(
                snapshot: snapshot,
                recentBubbles: recentBubbles,
                recentCaptures: recentCaptures,
                typeSummaries: typeSummaries,
                captureSummaries: captureSummaries,
                hostSummaries: hostSummaries,
                appSummaries: appSummaries,
                conversationSummaries: conversationSummaries,
                fileSummaries: fileSummaries,
                folderSummaries: folderSummaries,
                recentSearches: recentSearches
            )

            HStack(spacing: 10) {
                StatChip(label: "Bubbles", value: "\(store.bubbles.count)")
                StatChip(label: store.hasPendingAutosave ? "Saving" : "Last Save", value: lastSavedLabel())
                StatChip(label: "Sync", value: cloudSync.title)
            }

            Text(store.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .frame(maxWidth: 360, alignment: .leading)
        .onExitCommand {
            guard !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            store.searchQuery = ""
            searchFieldFocused = false
        }
    }

    private func searchHintText(for snapshot: BubbleSearchSnapshot) -> String {
        let trimmedQuery = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let isRecentSearch = !trimmedQuery.isEmpty && store.recentSearches.contains {
            $0.caseInsensitiveCompare(trimmedQuery) == .orderedSame
        }

        if snapshot.isExactPhrase {
            return isRecentSearch
                ? "Exact phrase mode is on. This search is also in your recent trails. Press Escape to clear search."
                : "Exact phrase mode is on. Press Escape to clear search."
        }

        if snapshot.isActive {
            return isRecentSearch
                ? "This search is in your recent trails. Put words in quotes for an exact phrase."
                : "Tip: put words in quotes to search for an exact phrase."
        }

        return "Tip: Command-F focuses search, and quoted words look for an exact phrase."
    }

    @ViewBuilder
    private func contentSection(
        snapshot: BubbleSearchSnapshot,
        recentBubbles: [Bubble],
        recentCaptures: [Bubble],
        typeSummaries: [(type: BubbleType, count: Int, query: String)],
        captureSummaries: [(label: String, count: Int, query: String)],
        hostSummaries: [(host: String, count: Int)],
        appSummaries: [(app: String, count: Int)],
        conversationSummaries: [(conversation: String, count: Int)],
        fileSummaries: [(file: String, count: Int)],
        folderSummaries: [(folder: String, count: Int)],
        recentSearches: [String]
    ) -> some View {
        let queryIsActive = snapshot.isActive
        let hasResults = !snapshot.direct.isEmpty || !snapshot.related.isEmpty

        if queryIsActive {
            searchOverview(snapshot: snapshot)
        }

        if queryIsActive && !snapshot.relatedTerms.isEmpty {
            nearbyIdeasSection(snapshot: snapshot)
        }

        if queryIsActive && hasResults {
            searchResultsSection(snapshot: snapshot)
        } else if queryIsActive {
            emptySearchSection(snapshot: snapshot)
        } else {
            retrievalSection(
                recentBubbles: recentBubbles,
                recentCaptures: recentCaptures,
                typeSummaries: typeSummaries,
                captureSummaries: captureSummaries,
                hostSummaries: hostSummaries,
                appSummaries: appSummaries,
                conversationSummaries: conversationSummaries,
                fileSummaries: fileSummaries,
                folderSummaries: folderSummaries,
                recentSearches: recentSearches
            )
        }
    }

    private func searchOverview(snapshot: BubbleSearchSnapshot) -> some View {
        let selectedResultBubble: Bubble? = { () -> Bubble? in
            guard let selectedId = store.selectedId else { return nil }
            if let directBubble = snapshot.direct.first(where: { $0.bubble.id == selectedId })?.bubble {
                return directBubble
            }
            return snapshot.related.first(where: { $0.bubble.id == selectedId })?.bubble
        }()

        let selectedResultKind: String? = {
            guard let selectedId = store.selectedId else { return nil }
            if snapshot.direct.contains(where: { $0.bubble.id == selectedId }) {
                return "In direct matches"
            }
            if snapshot.related.contains(where: { $0.bubble.id == selectedId }) {
                return "In related matches"
            }
            return nil
        }()

        return VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.isExactPhrase
                ? "Exact phrase search keeps only bubbles containing the quoted wording floating on the canvas."
                : "Search view keeps direct matches and tangentially related bubbles floating on the canvas.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selectedResultKind, let selectedResultBubble {
                Button {
                    HapticsService.shared.perform(.open)
                    store.select(selectedResultBubble.id)
                } label: {
                    Text("\(selectedResultKind): \(selectedResultBubble.shortLabel)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Jump to the current bubble in these results")
            }

            if store.bubbles.contains(where: { $0.tags.contains(snapshot.query) }) {
                Text("Filtering by tag: \(snapshot.displayQuery)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                SearchCountChip(label: "Direct", count: snapshot.direct.count)
                SearchCountChip(label: "Related", count: snapshot.related.count)
            }
        }
    }

    private func nearbyIdeasSection(snapshot: BubbleSearchSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nearby ideas BubblePath is also checking")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 6) {
                ForEach(snapshot.relatedTerms.prefix(8), id: \.self) { term in
                    let isActiveTerm = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(term) == .orderedSame
                    Button {
                        store.searchQuery = term
                    } label: {
                        Text(term)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(isActiveTerm ? .primary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background((isActiveTerm ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func searchResultsSection(snapshot: BubbleSearchSnapshot) -> some View {
        let returnTarget = snapshot.direct.first?.bubble ?? snapshot.related.first?.bubble

        VStack(alignment: .leading, spacing: 8) {
            if let returnTarget {
                let isSelectedTarget = store.selectedId == returnTarget.id

                Button {
                    HapticsService.shared.perform(.open)
                    store.select(returnTarget.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "return")
                            .font(.caption2.weight(.semibold))
                        Text("Return opens \(returnTarget.shortLabel).")
                            .font(.caption2.weight(.medium))
                        if isSelectedTarget {
                            Text("Selected")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(isSelectedTarget ? 0.36 : 0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(isSelectedTarget ? "This keyboard-targeted result is already open" : "Open the current keyboard-targeted result")
            }

            if !snapshot.direct.isEmpty {
                SearchGroupView(title: snapshot.isExactPhrase ? "Exact Phrase “\(snapshot.displayQuery)”" : "Contains “\(snapshot.displayQuery)”", kind: .direct, bubbles: snapshot.direct, isPrimaryGroup: true)
            }
            if !snapshot.related.isEmpty {
                SearchGroupView(title: "Tangentially Related", kind: .related, bubbles: snapshot.related, isPrimaryGroup: snapshot.direct.isEmpty)
            }
        }
    }

    private func emptySearchSection(snapshot: BubbleSearchSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No bubbles match “\(snapshot.displayQuery)” yet.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(snapshot.isExactPhrase
                ? "Try a broader search without quotes, clear the search, or capture a new bubble into this part of your memory web."
                : "Try a nearby idea above, clear the search, or capture a new bubble into this part of your memory web.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func retrievalSection(
        recentBubbles: [Bubble],
        recentCaptures: [Bubble],
        typeSummaries: [(type: BubbleType, count: Int, query: String)],
        captureSummaries: [(label: String, count: Int, query: String)],
        hostSummaries: [(host: String, count: Int)],
        appSummaries: [(app: String, count: Int)],
        conversationSummaries: [(conversation: String, count: Int)],
        fileSummaries: [(file: String, count: Int)],
        folderSummaries: [(folder: String, count: Int)],
        recentSearches: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Recent Searches")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           recentSearches.contains(where: { $0.caseInsensitiveCompare(store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }) {
                            Text("Current")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clear") {
                            store.clearRecentSearches()
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                        ForEach(recentSearches, id: \.self) { query in
                            let isActiveQuery = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(query) == .orderedSame
                            let isExactQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\"")
                                && query.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("\"")
                            HStack(spacing: 4) {
                                Button {
                                    store.searchQuery = query
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(query)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(isActiveQuery ? .primary : .secondary)
                                            .lineLimit(1)
                                        if isExactQuery {
                                            Text("Exact")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(isActiveQuery ? .primary : .secondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    store.removeRecentSearch(query)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(isActiveQuery ? .primary : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .background(Color.white.opacity(isActiveQuery ? 0.30 : 0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .help("Remove this recent search")
                            }
                            .background((isActiveQuery ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isActiveQuery ? Color.white.opacity(0.34) : Color.white.opacity(0.16), lineWidth: 1)
                            )
                            .help("Reuse or remove this recent search")
                        }
                    }
                }
            }

            if !typeSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bubble Types")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Filter the web by idea, question, core truth, reference, or chat mode.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                        ForEach(typeSummaries, id: \.type) { summary in
                            let isActiveType = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.query) == .orderedSame
                            Button {
                                store.searchQuery = summary.query
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: summary.type.bubbleStyle.iconName)
                                    Text(summary.type.label)
                                    Text("\(summary.count)")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isActiveType ? .primary : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background((isActiveType ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !captureSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capture Lanes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Revisit things by what they are: webpages, clipped selections, chats, or notes.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                        ForEach(captureSummaries, id: \.label) { summary in
                            let isActiveLane = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.query) == .orderedSame
                            Button {
                                store.searchQuery = summary.query
                            } label: {
                                HStack(spacing: 6) {
                                    Text(summary.label)
                                    Text("\(summary.count)")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isActiveLane ? .primary : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background((isActiveLane ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !hostSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source Hosts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Revisit material by where it came from.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                        ForEach(hostSummaries, id: \.host) { summary in
                            let isActiveHost = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.host) == .orderedSame
                            Button {
                                store.searchQuery = summary.host
                            } label: {
                                HStack(spacing: 6) {
                                    Text(summary.host)
                                    Text("\(summary.count)")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isActiveHost ? .primary : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background((isActiveHost ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !appSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source Apps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Trace imports back through clipboard, manual capture, or other intake paths.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                        ForEach(appSummaries, id: \.app) { summary in
                            let isActiveApp = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.app) == .orderedSame
                            Button {
                                store.searchQuery = summary.app
                            } label: {
                                HStack(spacing: 6) {
                                    Text(summary.app)
                                    Text("\(summary.count)")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isActiveApp ? .primary : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background((isActiveApp ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !conversationSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source Conversations")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Revisit imported thought clusters by the conversation they came from.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                        ForEach(conversationSummaries, id: \.conversation) { summary in
                            let isActiveConversation = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.conversation) == .orderedSame
                            Button {
                                store.searchQuery = summary.conversation
                            } label: {
                                HStack(spacing: 6) {
                                    Text(summary.conversation)
                                        .lineLimit(1)
                                    Text("\(summary.count)")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isActiveConversation ? .primary : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background((isActiveConversation ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !fileSummaries.isEmpty {
                SourceFilesLane(fileSummaries: fileSummaries, laneColumns: laneColumns)
            }

            if !folderSummaries.isEmpty {
                SourceFoldersLane(folderSummaries: folderSummaries, laneColumns: laneColumns)
            }

            if !recentBubbles.isEmpty {
                RecentBubbleSection(
                    title: "Jump Back In",
                    detail: "The thoughts you touched most recently.",
                    bubbles: recentBubbles
                )
            }

            if !recentCaptures.isEmpty {
                RecentBubbleSection(
                    title: "Captured Lately",
                    detail: "Webpages, excerpts, and chats you pulled into BubblePath.",
                    bubbles: recentCaptures
                )
            }
        }
    }

    private func lastSavedLabel() -> String {
        if store.hasPendingAutosave {
            return "Autosaving..."
        }
        guard let lastSavedAt = store.lastSavedAt else {
            return "Not yet"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: lastSavedAt)
    }
}

private struct RecentBubbleSection: View {
    @EnvironmentObject private var store: BubbleStore

    let title: String
    let detail: String
    let bubbles: [Bubble]

    var body: some View {
        let selectedBubbleInLane = bubbles.first { $0.id == store.selectedId }
        let orderedBubbles = orderedLaneBubbles(selectedBubbleInLane: selectedBubbleInLane)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let selectedBubbleInLane {
                    Button {
                        HapticsService.shared.perform(.open)
                        store.select(selectedBubbleInLane.id)
                    } label: {
                        Text("Current: \(selectedBubbleInLane.shortLabel)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Jump to the current bubble in this lane")
                }
            }

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(Array(orderedBubbles.enumerated()), id: \.element.id) { index, bubble in
                let isSelectedBubble = store.selectedId == bubble.id
                let isLaneAnchor = index == 0 && isSelectedBubble

                Button {
                    HapticsService.shared.perform(.open)
                    store.select(bubble.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(accent(for: bubble))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(bubble.shortLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if isSelectedBubble {
                                    Text("Open")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                if isLaneAnchor {
                                    Text("Top of lane")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                if let captureSourceLabel = bubble.captureSourceLabel,
                                   let captureSourceQuery = bubble.captureSourceQuery {
                                    let isActiveSourceType = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(captureSourceQuery) == .orderedSame
                                    Button {
                                        store.searchQuery = captureSourceQuery
                                    } label: {
                                        Text(captureSourceLabel)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(isActiveSourceType ? .primary : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let sourceHostLabel = bubble.sourceHostLabel {
                                    let isActiveHost = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceHostLabel) == .orderedSame
                                    Button {
                                        store.searchQuery = sourceHostLabel
                                    } label: {
                                        Text(sourceHostLabel)
                                            .font(.caption2)
                                            .foregroundStyle(isActiveHost ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let sourceFileURL = bubble.sourceFileURL {
                                    let sourceFileQuery = bubble.sourceFileLocationLabel ?? sourceFileURL.lastPathComponent
                                    let isActiveFileURL = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceFileQuery) == .orderedSame
                                    Button {
                                        store.searchQuery = sourceFileQuery
                                    } label: {
                                        Text("Local file")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(isActiveFileURL ? .primary : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let sourceAppLabel = bubble.sourceAppLabel {
                                    let isActiveApp = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceAppLabel) == .orderedSame
                                    Button {
                                        store.searchQuery = sourceAppLabel
                                    } label: {
                                        Text(sourceAppLabel)
                                            .font(.caption2)
                                            .foregroundStyle(isActiveApp ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let sourceConversationLabel = bubble.sourceConversationLabel {
                                    let isActiveConversation = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceConversationLabel) == .orderedSame
                                    Button {
                                        store.searchQuery = sourceConversationLabel
                                    } label: {
                                        Text(sourceConversationLabel)
                                            .font(.caption2)
                                            .foregroundStyle(isActiveConversation ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let sourceConversationIDLabel = bubble.sourceConversationIDLabel {
                                    let isActiveConversationID = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceConversationIDLabel) == .orderedSame
                                    Button {
                                        store.searchQuery = sourceConversationIDLabel
                                    } label: {
                                        Text(sourceConversationIDLabel)
                                            .font(.caption2)
                                            .foregroundStyle(isActiveConversationID ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(bubble.sourceFileLabels.prefix(2), id: \.self) { sourceFileLabel in
                                    let isActiveFile = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceFileLabel) == .orderedSame
                                    Button {
                                        store.searchQuery = sourceFileLabel
                                    } label: {
                                        Text(sourceFileLabel)
                                            .font(.caption2)
                                            .foregroundStyle(isActiveFile ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text(bubble.displayBody.isEmpty ? bubble.memoryScope.label : bubble.displayBody)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            Text(relativeTimestamp(for: bubble.lastEditedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(isSelectedBubble ? 0.48 : 0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelectedBubble ? Color.white.opacity(0.28) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func orderedLaneBubbles(selectedBubbleInLane: Bubble?) -> [Bubble] {
        guard let selectedBubbleInLane else { return bubbles }
        return [selectedBubbleInLane] + bubbles.filter { $0.id != selectedBubbleInLane.id }
    }

    private func accent(for bubble: Bubble) -> Color {
        bubble.type.bubbleStyle.accentColor
    }

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Touched \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

private struct SearchCountChip: View {
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
            Text("\(count)")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SourceFilesLane: View {
    @EnvironmentObject private var store: BubbleStore

    let fileSummaries: [(file: String, count: Int)]
    let laneColumns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source Files")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Revisit dropped text, document, image, audio, and video files by filename.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                ForEach(fileSummaries, id: \.file) { summary in
                    let isActiveFile = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.file) == .orderedSame
                    Button {
                        store.searchQuery = summary.file
                    } label: {
                        HStack(spacing: 6) {
                            Text(summary.file)
                                .lineLimit(1)
                            Text("\(summary.count)")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isActiveFile ? .primary : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background((isActiveFile ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SourceFoldersLane: View {
    @EnvironmentObject private var store: BubbleStore

    let folderSummaries: [(folder: String, count: Int)]
    let laneColumns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source Folders")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Revisit local captures by the folder they came from.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 6) {
                ForEach(folderSummaries, id: \.folder) { summary in
                    let isActiveFolder = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(summary.folder) == .orderedSame
                    Button {
                        store.searchQuery = summary.folder
                    } label: {
                        HStack(spacing: 6) {
                            Text(summary.folder)
                                .lineLimit(1)
                            Text("\(summary.count)")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isActiveFolder ? .primary : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background((isActiveFolder ? Color.white.opacity(0.48) : Color.white.opacity(0.3)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SearchGroupView: View {
    @EnvironmentObject private var store: BubbleStore

    let title: String
    let kind: SearchMatchKind
    let bubbles: [BubbleSearchMatch]
    let isPrimaryGroup: Bool

    var body: some View {
        let selectedBubbleInGroup = bubbles.first { $0.bubble.id == store.selectedId }?.bubble

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let selectedBubbleInGroup {
                    Button {
                        HapticsService.shared.perform(.open)
                        store.select(selectedBubbleInGroup.id)
                    } label: {
                        Text("Current: \(selectedBubbleInGroup.shortLabel)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Jump to the current bubble in this result section")
                }
            }

            ForEach(Array(bubbles.enumerated()), id: \.element.id) { index, match in
                SearchMatchCard(kind: kind, match: match, isPrimaryReturnTarget: isPrimaryGroup && index == 0)
            }
        }
    }
}

private struct SearchMatchCard: View {
    @EnvironmentObject private var store: BubbleStore

    let kind: SearchMatchKind
    let match: BubbleSearchMatch
    let isPrimaryReturnTarget: Bool

    private let tagColumns = [GridItem(.adaptive(minimum: 56), spacing: 6)]

    private var accentColor: Color {
        kind == .direct
            ? Color(red: 0.31, green: 0.59, blue: 0.69)
            : Color(red: 0.63, green: 0.57, blue: 0.39)
    }

    var body: some View {
        let linkedBubbles = store.linkedBubbles(for: match.bubble, limit: 3)
        let isSelectedBubble = store.selectedId == match.bubble.id

        VStack(alignment: .leading, spacing: 6) {
            Button {
                HapticsService.shared.perform(.open)
                store.select(match.bubble.id)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text(match.bubble.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if isPrimaryReturnTarget {
                            Label("Return", systemImage: "return")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        if isSelectedBubble {
                            Text("Open")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    if let captureSourceLabel = match.bubble.captureSourceLabel {
                        HStack(spacing: 6) {
                            if let captureSourceQuery = match.bubble.captureSourceQuery {
                                let isActiveSourceType = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(captureSourceQuery) == .orderedSame
                                Button {
                                    store.searchQuery = captureSourceQuery
                                } label: {
                                    Text(captureSourceLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(isActiveSourceType ? .primary : .secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(captureSourceLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            if let sourceHostLabel = match.bubble.sourceHostLabel {
                                Button {
                                    store.searchQuery = sourceHostLabel
                                } label: {
                                    Text(sourceHostLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                            if let sourceFileURL = match.bubble.sourceFileURL {
                                let sourceFileQuery = match.bubble.sourceFileLocationLabel ?? sourceFileURL.lastPathComponent
                                Button {
                                    store.searchQuery = sourceFileQuery
                                } label: {
                                    Text("Local file")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            if let sourceAppLabel = match.bubble.sourceAppLabel {
                                Button {
                                    store.searchQuery = sourceAppLabel
                                } label: {
                                    Text(sourceAppLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                            if let sourceConversationLabel = match.bubble.sourceConversationLabel {
                                Button {
                                    store.searchQuery = sourceConversationLabel
                                } label: {
                                    Text(sourceConversationLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                            if let sourceConversationIDLabel = match.bubble.sourceConversationIDLabel {
                                Button {
                                    store.searchQuery = sourceConversationIDLabel
                                } label: {
                                    Text(sourceConversationIDLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(match.bubble.sourceFileLabels.prefix(2), id: \.self) { sourceFileLabel in
                                Button {
                                    store.searchQuery = sourceFileLabel
                                } label: {
                                    Text(sourceFileLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Text(match.reason)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(match.snippet ?? (match.bubble.displayBody.isEmpty ? match.bubble.memoryScope.label : match.bubble.displayBody))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if !match.bubble.tags.isEmpty {
                LazyVGrid(columns: tagColumns, alignment: .leading, spacing: 6) {
                    ForEach(Array(match.bubble.tags.prefix(4)), id: \.self) { tag in
                        Button {
                            store.searchQuery = tag
                        } label: {
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !linkedBubbles.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Connected bubbles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: tagColumns, alignment: .leading, spacing: 6) {
                        ForEach(linkedBubbles, id: \.id) { linkedBubble in
                            Button {
                                HapticsService.shared.perform(.select)
                                store.select(linkedBubble.id)
                            } label: {
                                Text(linkedBubble.shortLabel)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background((isPrimaryReturnTarget || isSelectedBubble ? Color.white.opacity(0.5) : Color.white.opacity(0.34)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isPrimaryReturnTarget
                            ? accentColor.opacity(0.32)
                            : (isSelectedBubble ? Color.white.opacity(0.26) : Color.clear),
                        lineWidth: 1.2
                    )

                if isPrimaryReturnTarget {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.9))
                        .frame(width: 3)
                        .padding(.vertical, 7)
                        .padding(.leading, 1)
                }
            }
        )
        .shadow(color: isPrimaryReturnTarget ? accentColor.opacity(0.12) : (isSelectedBubble ? Color.black.opacity(0.06) : .clear), radius: 10, y: 4)
    }
}

private struct UtilityPanel: View {
    @EnvironmentObject private var store: BubbleStore
    let onNewBubble: () -> Void
    let onRevealImportPrepSet: () -> Void
    let onOpenImportGuide: () -> Void
    let onCopyImportGuide: () -> Void
    let onOpenImportChecklist: () -> Void
    let onCopyImportChecklist: () -> Void
    let onOpenServerQuickStart: () -> Void
    let onCopyServerQuickStart: () -> Void
    let onOpenPhoneAccessPlan: () -> Void
    let onCopyPhoneAccessPlan: () -> Void
    let onOpenServerCommandsGuide: () -> Void
    let onCopyServerCommandsGuide: () -> Void
    let onOpenTermiusQuickConnect: () -> Void
    let onCopyTermiusQuickConnect: () -> Void
    let onOpenChatHistoryShapeGuide: () -> Void
    let onCopyChatHistoryShapeGuide: () -> Void
    let onOpenChatHistoryCommandsGuide: () -> Void
    let onCopyChatHistoryCommandsGuide: () -> Void
    let onRevealDistillPrompt: () -> Void
    let onCopyDistillPrompt: () -> Void
    let onRevealImportTemplate: () -> Void
    let onCopyImportTemplate: () -> Void
    let onRevealImportValidator: () -> Void
    let onRevealImportWrapper: () -> Void
    let onRevealInvalidChatHistoryExample: () -> Void
    let onRevealMinimalChatHistoryExample: () -> Void
    let onCopyMinimalChatHistoryExample: () -> Void
    let onRevealArrayChatHistoryExample: () -> Void
    let onCopyArrayChatHistoryExample: () -> Void
    let onRevealObjectChatHistoryExample: () -> Void
    let onCopyObjectChatHistoryExample: () -> Void
    let onRevealSingleEntryChatHistoryExample: () -> Void
    let onCopySingleEntryChatHistoryExample: () -> Void
    let onRevealGPTFencedChatHistoryExample: () -> Void
    let onCopyGPTFencedChatHistoryExample: () -> Void
    let onRevealGPTEmbeddedChatHistoryExample: () -> Void
    let onCopyGPTEmbeddedChatHistoryExample: () -> Void
    let onRevealGPTPlainTextChatHistoryExample: () -> Void
    let onCopyGPTPlainTextChatHistoryExample: () -> Void
    let onRevealGPTDOCChatHistoryExample: () -> Void
    let onCopyGPTDOCChatHistoryExample: () -> Void
    let onRevealGPTDOCXChatHistoryExample: () -> Void
    let onCopyGPTDOCXChatHistoryExample: () -> Void
    let onRevealGPTODTChatHistoryExample: () -> Void
    let onCopyGPTODTChatHistoryExample: () -> Void
    let onRevealGPTRTFChatHistoryExample: () -> Void
    let onCopyGPTRTFChatHistoryExample: () -> Void
    let onRevealGPTHTMLChatHistoryExample: () -> Void
    let onCopyGPTHTMLChatHistoryExample: () -> Void
    let onRevealGPTPDFChatHistoryExample: () -> Void
    let onCopyGPTPDFChatHistoryExample: () -> Void
    let onRevealGPTWebArchiveChatHistoryExample: () -> Void
    let onCopyGPTWebArchiveChatHistoryExample: () -> Void
    let onRevealGPTEmbeddedPlusFenceChatHistoryExample: () -> Void
    let onCopyGPTEmbeddedPlusFenceChatHistoryExample: () -> Void
    let onRevealGPTFencePlusEmbeddedChatHistoryExample: () -> Void
    let onCopyGPTFencePlusEmbeddedChatHistoryExample: () -> Void
    let onRevealGPTMultiEmbeddedChatHistoryExample: () -> Void
    let onCopyGPTMultiEmbeddedChatHistoryExample: () -> Void
    let onRevealGPTMultiFenceChatHistoryExample: () -> Void
    let onCopyGPTMultiFenceChatHistoryExample: () -> Void
    let onCapture: () -> Void
    let onCaptureClipboard: () -> Void
    let onImportClipboardJSON: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onSave: () -> Void
    let onReload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button("New Bubble", action: onNewBubble)
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Create a new bubble")
                Button("Capture", action: onCapture)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .help("New manual capture")
                Button("Clipboard", action: onCaptureClipboard)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .help("Capture from clipboard")
                Button("Import Clipboard", action: onImportClipboardJSON)
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .help("Import BubblePath JSON from the clipboard, including GPT-style responses with extra text, or use File > Import Clipboard JSON")
                Button("Import", action: onImport)
                    .keyboardShortcut("o", modifiers: [.command])
                    .help("Import BubblePath JSON or saved GPT/webpage/document files such as JSON, markdown, DOC, DOCX, ODT, RTF, HTML, PDF, or webarchive")
                Button("Export", action: onExport)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Save", action: onSave)
                    .keyboardShortcut("s", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                Button("Reload", action: onReload)
                if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Clear Search") {
                        store.clearSearch()
                    }
                    .help("Return to the full bubble web")
                }
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                Button("Prep Set", action: onRevealImportPrepSet)
                    .help("Reveal the full import-prep file set in Finder")
                Button("Checklist", action: onOpenImportChecklist)
                    .help("Open the import prep checklist")
                Button("Copy Checklist", action: onCopyImportChecklist)
                    .help("Copy the import prep checklist")
                Button("Server Guide", action: onOpenServerQuickStart)
                    .help("Open the BubblePath server quick start")
                Button("Copy Server", action: onCopyServerQuickStart)
                    .help("Copy the BubblePath server quick start")
                Button("Phone Plan", action: onOpenPhoneAccessPlan)
                    .help("Open the BubblePath phone access plan")
                Button("Copy Phone", action: onCopyPhoneAccessPlan)
                    .help("Copy the BubblePath phone access plan")
                Button("Server Cmds", action: onOpenServerCommandsGuide)
                    .help("Open the BubblePath server commands guide")
                Button("Copy Cmds", action: onCopyServerCommandsGuide)
                    .help("Copy the BubblePath server commands guide")
                Button("Termius", action: onOpenTermiusQuickConnect)
                    .help("Open the Termius quick connect guide")
                Button("Copy Termius", action: onCopyTermiusQuickConnect)
                    .help("Copy the Termius quick connect guide")
                Button("Import Guide", action: onOpenImportGuide)
                    .help("Open the chat-history import guide")
                Button("Copy Guide", action: onCopyImportGuide)
                    .help("Copy the chat-history import guide")
                Button("Shape Guide", action: onOpenChatHistoryShapeGuide)
                    .help("Open the direct-import vs wrapper guide")
                Button("Copy Shape", action: onCopyChatHistoryShapeGuide)
                    .help("Copy the direct-import vs wrapper guide")
                Button("Commands", action: onOpenChatHistoryCommandsGuide)
                    .help("Open the validate and wrap command guide")
                Button("Copy Commands", action: onCopyChatHistoryCommandsGuide)
                    .help("Copy the validate and wrap command guide")
                Button("Prompt", action: onRevealDistillPrompt)
                    .help("Reveal the chat-history distill prompt")
                Button("Copy Prompt", action: onCopyDistillPrompt)
                    .help("Copy the chat-history distill prompt")
                Button("Template", action: onRevealImportTemplate)
                    .help("Reveal the chat-history batch template file")
                Button("Copy Template", action: onCopyImportTemplate)
                    .help("Copy the chat-history batch template")
                Button("Validator", action: onRevealImportValidator)
                    .help("Reveal the local chat-history validator command")
                Button("Wrapper", action: onRevealImportWrapper)
                    .help("Reveal the local chat-history wrapper command")
                Button("Minimal", action: onRevealMinimalChatHistoryExample)
                    .help("Reveal the minimal valid chat-history example")
                Button("Copy Minimal", action: onCopyMinimalChatHistoryExample)
                    .help("Copy the minimal valid chat-history example")
                Button("Array", action: onRevealArrayChatHistoryExample)
                    .help("Reveal the root-array chat-history example")
                Button("Copy Array", action: onCopyArrayChatHistoryExample)
                    .help("Copy the root-array chat-history example")
                Button("Object", action: onRevealObjectChatHistoryExample)
                    .help("Reveal the root-object chat-history example")
                Button("Copy Object", action: onCopyObjectChatHistoryExample)
                    .help("Copy the root-object chat-history example")
                Button("Single Entry", action: onRevealSingleEntryChatHistoryExample)
                    .help("Reveal the single-entry chat-history example")
                Button("Copy Single", action: onCopySingleEntryChatHistoryExample)
                    .help("Copy the single-entry chat-history example")
                Button("GPT Fenced", action: onRevealGPTFencedChatHistoryExample)
                    .help("Reveal the GPT-style fenced JSON response example")
                Button("Copy GPT Fenced", action: onCopyGPTFencedChatHistoryExample)
                    .help("Copy the GPT-style fenced JSON response example")
                Button("GPT Embedded", action: onRevealGPTEmbeddedChatHistoryExample)
                    .help("Reveal the GPT-style embedded JSON response example")
                Button("Copy GPT Embedded", action: onCopyGPTEmbeddedChatHistoryExample)
                    .help("Copy the GPT-style embedded JSON response example")
                Button("GPT Plain", action: onRevealGPTPlainTextChatHistoryExample)
                    .help("Reveal the GPT-style plain-text JSON response example")
                Button("Copy GPT Plain", action: onCopyGPTPlainTextChatHistoryExample)
                    .help("Copy the GPT-style plain-text JSON response example")
                Button("GPT DOC", action: onRevealGPTDOCChatHistoryExample)
                    .help("Reveal the GPT-style saved DOC response example")
                Button("Copy GPT DOC", action: onCopyGPTDOCChatHistoryExample)
                    .help("Copy the GPT-style saved DOC response example")
                Button("GPT DOCX", action: onRevealGPTDOCXChatHistoryExample)
                    .help("Reveal the GPT-style saved DOCX response example")
                Button("Copy GPT DOCX", action: onCopyGPTDOCXChatHistoryExample)
                    .help("Copy the GPT-style saved DOCX response example")
                Button("GPT ODT", action: onRevealGPTODTChatHistoryExample)
                    .help("Reveal the GPT-style saved ODT response example")
                Button("Copy GPT ODT", action: onCopyGPTODTChatHistoryExample)
                    .help("Copy the GPT-style saved ODT response example")
                Button("GPT RTF", action: onRevealGPTRTFChatHistoryExample)
                    .help("Reveal the GPT-style saved RTF response example")
                Button("Copy GPT RTF", action: onCopyGPTRTFChatHistoryExample)
                    .help("Copy the GPT-style saved RTF response example")
                Button("GPT HTML", action: onRevealGPTHTMLChatHistoryExample)
                    .help("Reveal the GPT-style saved HTML response example")
                Button("Copy GPT HTML", action: onCopyGPTHTMLChatHistoryExample)
                    .help("Copy the GPT-style saved HTML response example")
                Button("GPT PDF", action: onRevealGPTPDFChatHistoryExample)
                    .help("Reveal the GPT-style saved PDF response example")
                Button("Copy GPT PDF", action: onCopyGPTPDFChatHistoryExample)
                    .help("Copy the GPT-style saved PDF response example")
                Button("GPT Webarchive", action: onRevealGPTWebArchiveChatHistoryExample)
                    .help("Reveal the GPT-style saved webarchive response example")
                Button("Copy GPT Webarchive", action: onCopyGPTWebArchiveChatHistoryExample)
                    .help("Copy the GPT-style saved webarchive response example")
                Button("GPT Embedded + Fence", action: onRevealGPTEmbeddedPlusFenceChatHistoryExample)
                    .help("Reveal the GPT-style response with an irrelevant embedded block before fenced BubblePath JSON")
                Button("Copy GPT Embedded + Fence", action: onCopyGPTEmbeddedPlusFenceChatHistoryExample)
                    .help("Copy the GPT-style response with an irrelevant embedded block before fenced BubblePath JSON")
                Button("GPT Fence + Embedded", action: onRevealGPTFencePlusEmbeddedChatHistoryExample)
                    .help("Reveal the GPT-style response with an irrelevant fenced block before embedded BubblePath JSON")
                Button("Copy GPT Fence + Embedded", action: onCopyGPTFencePlusEmbeddedChatHistoryExample)
                    .help("Copy the GPT-style response with an irrelevant fenced block before embedded BubblePath JSON")
                Button("GPT Multi Embedded", action: onRevealGPTMultiEmbeddedChatHistoryExample)
                    .help("Reveal the GPT-style multi-embedded JSON response example")
                Button("Copy GPT Multi Embedded", action: onCopyGPTMultiEmbeddedChatHistoryExample)
                    .help("Copy the GPT-style multi-embedded JSON response example")
                Button("GPT Multi Fence", action: onRevealGPTMultiFenceChatHistoryExample)
                    .help("Reveal the GPT-style multi-fence JSON response example")
                Button("Copy GPT Multi Fence", action: onCopyGPTMultiFenceChatHistoryExample)
                    .help("Copy the GPT-style multi-fence JSON response example")
                Button("Bad Example", action: onRevealInvalidChatHistoryExample)
                    .help("Reveal the invalid chat-history example file")
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 6) {
                Text(store.usingSharedProjectVault ? "Shared project vault" : "Imported custom vault")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(store.vaultURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text("\(store.backupInfo.regularCount) backups, \(store.backupInfo.preRestoreCount) restore checkpoints")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Shortcuts: Command-F search, Return opens the first result, Escape clears search, Command-N new bubble, Command-S save, Command-O import, Command-Shift-E export, Command-Shift-N capture, Command-Shift-V clipboard, Command-Shift-I import clipboard JSON. File > Import Clipboard JSON works too.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .frame(maxWidth: 360, alignment: .leading)
    }
}

private struct CaptureImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BubbleStore

    let seed: CaptureImportSeed?

    @State private var sourceType: BubbleCaptureSourceType = .webpage
    @State private var sourceTitle = ""
    @State private var sourceURLString = ""
    @State private var suggestedTitle = ""
    @State private var capturedText = ""
    @State private var appendToSelected = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Source", selection: $sourceType) {
                    ForEach(BubbleCaptureSourceType.allCases) { type in
                        Text(label(for: type)).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Text(sourceDescription(for: sourceType))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let captureOriginNote {
                    Text(captureOriginNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Source title", text: $sourceTitle)
                    .textFieldStyle(.roundedBorder)

                TextField("Source URL", text: $sourceURLString)
                    .textFieldStyle(.roundedBorder)

                if let sourceURLWarning {
                    Text(sourceURLWarning)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.72))
                }

                TextField("Bubble title", text: $suggestedTitle)
                    .textFieldStyle(.roundedBorder)

                if suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Suggested title: \(suggestedTitlePreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $capturedText)
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Toggle(isOn: $appendToSelected) {
                    Text("Append to the selected bubble")
                }
                .disabled(store.selectedBubble == nil)

                if let selected = store.selectedBubble {
                    if appendToSelected {
                        Text("Appending into “\(selected.shortLabel)”")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("BubblePath can also tuck this into “\(selected.shortLabel)” if it belongs with the thought you already have open.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("This capture will become a new bubble.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(22)
            .navigationTitle("Capture Into BubblePath")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Capture") {
                        saveCapture()
                    }
                    .disabled(captureSaveDisabled)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear {
            applySeedIfNeeded()
            if store.selectedBubble != nil {
                appendToSelected = true
            }
            autofillSuggestedTitleIfNeeded()
        }
        .onChange(of: sourceTitle) { _, _ in
            autofillSuggestedTitleIfNeeded()
        }
        .onChange(of: capturedText) { _, _ in
            autofillSuggestedTitleIfNeeded()
        }
    }

    private func saveCapture() {
        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = BubbleCapturePayload(
            sourceType: sourceType,
            sourceTitle: sourceTitle,
            sourceURL: trimmedURL.isEmpty ? nil : resolvedSourceURL,
            capturedText: capturedText,
            capturedAt: Date(),
            suggestedBubbleTitle: suggestedTitle,
            targetBubbleID: appendToSelected ? store.selectedId : nil,
            sourceApp: seed?.sourceApp ?? "Manual Capture"
        )

        store.importCapture(payload)
        dismiss()
    }

    private var captureSaveDisabled: Bool {
        capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sourceURLWarning != nil
    }

    private var resolvedSourceURL: URL? {
        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        guard let url = URL(string: trimmedURL), url.scheme != nil else { return nil }
        return url
    }

    private var sourceURLWarning: String? {
        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        guard resolvedSourceURL != nil else {
            return "Source URL needs to include a valid URL, like https://example.com or file:///path/to/file."
        }
        return nil
    }

    private func applySeedIfNeeded() {
        guard let seed else { return }
        sourceType = seed.sourceType
        sourceTitle = seed.sourceTitle
        sourceURLString = seed.sourceURLString
        suggestedTitle = seed.suggestedTitle
        capturedText = seed.capturedText
    }

    private var captureOriginNote: String? {
        guard let seed else { return nil }

        switch seed.sourceApp {
        case "Clipboard":
            return sourceType == .webpage
                ? "BubblePath pulled this from your clipboard and recognized it as a webpage."
                : "BubblePath pulled this from your clipboard and recognized it as captured text."
        case "Dropped Web Link":
            return "BubblePath recognized this dropped link as a webpage."
        case "Dropped Web Links":
            return "BubblePath gathered these dropped webpage links into one capture draft."
        case "Dropped Text File":
            return "BubblePath gathered readable text from the dropped file into this capture draft."
        case "Dropped Text Files":
            return "BubblePath gathered readable text from the dropped files into one capture draft."
        case "Dropped Image File":
            return "BubblePath prepared this dropped image file as a searchable capture draft."
        case "Dropped Image Files":
            return "BubblePath prepared these dropped image files as one searchable capture draft."
        case "Dropped Audio File":
            return "BubblePath prepared this dropped audio file as a searchable capture draft."
        case "Dropped Audio Files":
            return "BubblePath prepared these dropped audio files as one searchable capture draft."
        case "Dropped Video File":
            return "BubblePath prepared this dropped video file as a searchable capture draft."
        case "Dropped Video Files":
            return "BubblePath prepared these dropped video files as one searchable capture draft."
        case "Dropped Text":
            return sourceType == .webpage
                ? "BubblePath recognized this dropped link as a webpage."
                : "BubblePath turned the dropped text into a capture draft."
        default:
            return "BubblePath prepared this from \(seed.sourceApp)."
        }
    }

    private var suggestedTitlePreview: String {
        let trimmedSuggested = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSuggested.isEmpty {
            return trimmedSuggested
        }

        let trimmedSource = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSource.isEmpty {
            return trimmedSource
        }

        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let host = URL(string: trimmedURL)?.host(percentEncoded: false), !host.isEmpty {
            return host.replacingOccurrences(of: "www.", with: "")
        }

        let trimmedText = capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            return String(trimmedText.prefix(48))
        }

        return "Captured bubble"
    }

    private func autofillSuggestedTitleIfNeeded() {
        let trimmedSuggested = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSuggested.isEmpty else { return }
        suggestedTitle = suggestedTitlePreview
    }

    private func label(for type: BubbleCaptureSourceType) -> String {
        switch type {
        case .webpage:
            return "Webpage"
        case .textSelection:
            return "Selection"
        case .chatExport:
            return "Chat"
        case .note:
            return "Note"
        case .imageFile:
            return "Image"
        case .audioFile:
            return "Audio"
        case .videoFile:
            return "Video"
        }
    }

    private func sourceDescription(for type: BubbleCaptureSourceType) -> String {
        switch type {
        case .webpage:
            return "Capture a page title, URL, and the part you want to remember."
        case .textSelection:
            return "Capture a quote, paragraph, or excerpt from something you were reading."
        case .chatExport:
            return "Capture a saved exchange from ChatGPT or another conversation."
        case .note:
            return "Drop in a loose thought or fragment that belongs in your memory web."
        case .imageFile:
            return "Capture an image file as a searchable artifact with space for your notes."
        case .audioFile:
            return "Capture an audio file as a searchable artifact with space for your notes."
        case .videoFile:
            return "Capture a video file as a searchable artifact with space for your notes."
        }
    }
}

private struct CaptureImportSeed {
    let sourceType: BubbleCaptureSourceType
    let sourceTitle: String
    let sourceURLString: String
    let suggestedTitle: String
    let capturedText: String
    let sourceApp: String
}

private struct HintPanel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        )
        .frame(maxWidth: 280, alignment: .leading)
    }
}

private struct DropTargetOverlay: View {
    let title: String
    let detail: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.62), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(18)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
            )
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

private struct StatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
