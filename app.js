const storageKey = "bubblepath.v1";
const settingsKey = "bubblepath.settings.v1";
const serverThreadKey = "bubblepath.server.v1";
const notificationStateKey = "bubblepath.notify.v1";
const defaultGuidePrompt = [
  "You are the user's BubblePath thinking companion.",
  "Be warm, clear, honest, and grounded.",
  "Help turn messy thoughts into connected meaning without forcing structure too early.",
  "Ask one good question when that is more useful than giving advice.",
  "When the user wants action, help shape the next small concrete step."
].join(" ");
const colors = {
  thought: "#6c8b6f",
  question: "#70a9b2",
  decision: "#d86e5b",
  seed: "#d0a83d"
};

const starterBubbles = [
  {
    id: crypto.randomUUID(),
    type: "seed",
    content: "BubblePath is a place where conversation becomes creation.",
    createdAt: new Date().toISOString(),
    x: 42,
    y: 40,
    links: [],
    messages: [
      {
        id: crypto.randomUUID(),
        role: "note",
        text: "The first version should make capture feel immediate and structure feel optional.",
        createdAt: new Date().toISOString()
      }
    ]
  },
  {
    id: crypto.randomUUID(),
    type: "thought",
    content: "Small thoughts can compound into larger insights over time.",
    createdAt: new Date().toISOString(),
    x: 58,
    y: 58,
    links: [],
    messages: []
  }
];
starterBubbles[0].links = [starterBubbles[1].id];
starterBubbles[1].links = [starterBubbles[0].id];

let state = loadState();
let settings = loadSettings();
let serverThread = loadServerThread();
let selectedId = state.selectedId || state.bubbles[0]?.id || null;
let dragging = null;
let vaultSaveTimer = null;
let serverThreadSaveTimer = null;
let vaultAvailable = false;
let vaultDirty = true;
let serverThreadAvailable = false;
let serverThreadDirty = false;
let serverThreadSyncAt = "";
let serverThreadSyncTimer = null;
let serverDraftSyncTimer = null;
let notificationState = loadNotificationState();
let vaultInfo = {
  dataFile: "",
  backupFile: "",
  savedAt: "",
  backupCount: 0,
  regularBackupCount: 0,
  preRestoreBackupCount: 0,
  maxRegularBackups: 0,
  maxPreRestoreBackups: 0,
  minBackupIntervalMs: 0
};
let backups = [];
let toastTimer = null;
let deferredInstallPrompt = null;
let mobileView = loadMobileView();

const elements = {
  mobileNavButtons: Array.from(document.querySelectorAll(".mobile-nav-button")),
  form: document.querySelector("#bubble-form"),
  input: document.querySelector("#bubble-input"),
  type: document.querySelector("#bubble-type"),
  list: document.querySelector("#bubble-list"),
  count: document.querySelector("#bubble-count"),
  map: document.querySelector("#path-map"),
  links: document.querySelector("#link-layer"),
  empty: document.querySelector("#empty-state"),
  detailEmpty: document.querySelector("#detail-empty"),
  detailView: document.querySelector("#detail-view"),
  detailType: document.querySelector("#detail-type"),
  detailContent: document.querySelector("#detail-content"),
  detailMeta: document.querySelector("#detail-meta"),
  deleteBubble: document.querySelector("#delete-bubble"),
  linkSelect: document.querySelector("#link-select"),
  linkBubble: document.querySelector("#link-bubble"),
  linkedList: document.querySelector("#linked-list"),
  messages: document.querySelector("#messages"),
  messageCount: document.querySelector("#message-count"),
  messageForm: document.querySelector("#message-form"),
  messageInput: document.querySelector("#message-input"),
  askGpt: document.querySelector("#ask-gpt"),
  quickSaveVault: document.querySelector("#quick-save-vault"),
  saveVault: document.querySelector("#save-vault"),
  downloadVault: document.querySelector("#download-vault"),
  exportJson: document.querySelector("#export-json"),
  importJson: document.querySelector("#import-json"),
  importFile: document.querySelector("#import-file"),
  clearAll: document.querySelector("#clear-all"),
  autoArrange: document.querySelector("#auto-arrange"),
  buildOutput: document.querySelector("#build-output"),
  apiKey: document.querySelector("#api-key"),
  modelName: document.querySelector("#model-name"),
  guidePrompt: document.querySelector("#guide-prompt"),
  saveSettings: document.querySelector("#save-settings"),
  vaultStatus: document.querySelector("#vault-status"),
  vaultMode: document.querySelector("#vault-mode"),
  vaultDetail: document.querySelector("#vault-detail"),
  vaultBannerText: document.querySelector("#vault-banner-text"),
  backupSummary: document.querySelector("#backup-summary"),
  backupList: document.querySelector("#backup-list"),
  saveToast: document.querySelector("#save-toast"),
  clientOrigin: document.querySelector("#client-origin"),
  clientReach: document.querySelector("#client-reach"),
  clientHome: document.querySelector("#client-home"),
  clientInstall: document.querySelector("#client-install"),
  clientNotify: document.querySelector("#client-notify"),
  clientModeBanner: document.querySelector("#client-mode-banner"),
  clientModeActions: document.querySelector("#client-mode-actions"),
  clientLiveLink: document.querySelector("#client-live-link"),
  notifyPermission: document.querySelector("#notify-permission"),
  serverSubtitle: document.querySelector("#server-subtitle"),
  serverCount: document.querySelector("#server-count"),
  serverContext: document.querySelector("#server-context"),
  serverDocSubtitle: document.querySelector("#server-docs-subtitle"),
  serverDocCount: document.querySelector("#server-doc-count"),
  serverDocStatus: document.querySelector("#server-doc-status"),
  serverFileInput: document.querySelector("#server-file-input"),
  serverUrlInput: document.querySelector("#server-url-input"),
  serverUrlIngest: document.querySelector("#server-url-ingest"),
  serverDocuments: document.querySelector("#server-documents"),
  serverLiveChip: document.querySelector("#server-live-chip"),
  serverNeedsYou: document.querySelector("#server-needs-you"),
  serverNeedsYouText: document.querySelector("#server-needs-you-text"),
  serverMessages: document.querySelector("#server-messages"),
  serverForm: document.querySelector("#server-form"),
  serverComposeStatus: document.querySelector("#server-compose-status"),
  serverInput: document.querySelector("#server-input"),
  serverSend: document.querySelector("#server-send"),
  serverUseSelected: document.querySelector("#server-use-selected"),
  serverRefresh: document.querySelector("#server-refresh")
};

elements.mobileNavButtons.forEach((button) => {
  button.addEventListener("click", () => {
    mobileView = button.dataset.mobileView || "soap";
    saveMobileView();
    updateHashForMobileView();
    render();
  });
});

window.addEventListener("hashchange", () => {
  syncMobileViewFromHash();
  render();
});

window.addEventListener("resize", () => {
  renderMobileView();
});

window.addEventListener("focus", () => {
  markServerThreadSeen();
  render();
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") {
    markServerThreadSeen();
    render();
  }
});

hydrateSettings();
syncMobileViewFromHash();
primeNotificationState();
render();
loadVaultState();
registerServiceWorker();
setInterval(() => {
  if (vaultAvailable && vaultDirty) saveVaultNow();
  if (serverThreadAvailable && serverThreadDirty) saveServerThreadNow();
}, 10000);
serverThreadSyncTimer = setInterval(() => {
  if (serverThreadAvailable && !serverThreadDirty) {
    loadServerThreadFromServerWithOptions({ silent: true });
  }
}, 5000);

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  deferredInstallPrompt = event;
  render();
});

elements.notifyPermission.addEventListener("click", async () => {
  if (!("Notification" in window)) {
    render();
    return;
  }

  if (Notification.permission === "granted") {
    new Notification("Soap Bubbles is awake", {
      body: "This device is already allowed to alert you when Soap Server needs you."
    });
    return;
  }

  try {
    await Notification.requestPermission();
  } catch {
    // ignore and let render describe the current state
  }
  render();
});

elements.serverInput.addEventListener("input", () => {
  serverThread.draft = elements.serverInput.value;
  saveServerThread();
});

elements.form.addEventListener("submit", (event) => {
  event.preventDefault();
  const content = elements.input.value.trim();
  if (!content) return;

  const bubble = {
    id: crypto.randomUUID(),
    type: elements.type.value,
    content,
    createdAt: new Date().toISOString(),
    x: 35 + Math.random() * 30,
    y: 30 + Math.random() * 35,
    links: selectedId ? [selectedId] : [],
    messages: []
  };

  if (selectedId) {
    const current = getSelected();
    if (current && !current.links.includes(bubble.id)) current.links.push(bubble.id);
  }

  state.bubbles.unshift(bubble);
  selectedId = bubble.id;
  elements.input.value = "";
  saveAndRender();
});

document.querySelectorAll("[data-prompt]").forEach((button) => {
  button.addEventListener("click", () => {
    elements.input.value = button.dataset.prompt;
    elements.input.focus();
  });
});

elements.detailContent.addEventListener("input", () => {
  const bubble = getSelected();
  if (!bubble) return;
  bubble.content = elements.detailContent.value;
  saveAndRender({ keepFocus: true });
});

elements.deleteBubble.addEventListener("click", () => {
  if (!selectedId) return;
  state.bubbles = state.bubbles
    .filter((bubble) => bubble.id !== selectedId)
    .map((bubble) => ({ ...bubble, links: bubble.links.filter((id) => id !== selectedId) }));
  selectedId = state.bubbles[0]?.id || null;
  saveAndRender();
});

elements.linkBubble.addEventListener("click", () => {
  const bubble = getSelected();
  const targetId = elements.linkSelect.value;
  const target = state.bubbles.find((item) => item.id === targetId);
  if (!bubble || !target || bubble.id === target.id) return;

  if (!bubble.links.includes(target.id)) bubble.links.push(target.id);
  if (!target.links.includes(bubble.id)) target.links.push(bubble.id);
  saveAndRender();
});

elements.messageForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const bubble = getSelected();
  const text = elements.messageInput.value.trim();
  if (!bubble || !text) return;
  bubble.messages.push({
    id: crypto.randomUUID(),
    role: "note",
    text,
    createdAt: new Date().toISOString()
  });
  elements.messageInput.value = "";
  saveAndRender();
});

elements.askGpt.addEventListener("click", async () => {
  const bubble = getSelected();
  const text = elements.messageInput.value.trim();
  if (!bubble || !text) return;
  if (!settings.apiKey) {
    elements.buildOutput.textContent = "Add your OpenAI API key under Your GPT first, then save settings.";
    elements.apiKey.focus();
    return;
  }

  const userMessage = {
    id: crypto.randomUUID(),
    role: "user",
    text,
    createdAt: new Date().toISOString()
  };
  const pendingMessage = {
    id: crypto.randomUUID(),
    role: "assistant",
    text: "Thinking...",
    createdAt: new Date().toISOString(),
    pending: true
  };

  bubble.messages.push(userMessage, pendingMessage);
  elements.messageInput.value = "";
  saveAndRender();

  try {
    const answer = await askOpenAI(buildModelInput(bubble));
    pendingMessage.text = answer || "I did not get text back. Try again in a moment.";
  } catch (error) {
    pendingMessage.text = `OpenAI request failed: ${error.message}`;
  } finally {
    pendingMessage.pending = false;
    pendingMessage.createdAt = new Date().toISOString();
    saveAndRender();
  }
});

elements.serverUseSelected.addEventListener("click", () => {
  const bubble = getSelected();
  if (!bubble) {
    elements.serverInput.focus();
    return;
  }

  const intro = `Stay with this bubble for a minute: ${bubble.content}`;
  elements.serverInput.value = elements.serverInput.value.trim()
    ? `${elements.serverInput.value.trim()}\n\n${intro}`
    : intro;
  serverThread.draft = elements.serverInput.value;
  saveServerThread();
  elements.serverInput.focus();
});

elements.serverRefresh.addEventListener("click", async () => {
  elements.serverRefresh.disabled = true;
  try {
    await loadServerThreadFromServerWithOptions({});
  } finally {
    elements.serverRefresh.disabled = false;
  }
});

elements.serverFileInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;

  try {
    await ingestServerFile(file);
  } catch (error) {
    elements.serverDocStatus.textContent = `Document intake failed: ${error.message}`;
    render();
  } finally {
    event.target.value = "";
  }
});

elements.serverUrlIngest.addEventListener("click", async () => {
  const sourceUrl = elements.serverUrlInput.value.trim();
  if (!sourceUrl) {
    elements.serverUrlInput.focus();
    return;
  }

  try {
    await ingestServerUrl(sourceUrl);
  } catch (error) {
    elements.serverDocStatus.textContent = `Page intake failed: ${error.message}`;
    render();
  }
});

elements.serverForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const text = elements.serverInput.value.trim();
  if (!text) return;

  serverThread.messages.push({
    id: crypto.randomUUID(),
    role: "user",
    text,
    createdAt: new Date().toISOString()
  });
  elements.serverInput.value = "";
  serverThread.draft = "";

  const pendingMessage = {
    id: crypto.randomUUID(),
    role: "assistant",
    text: settings.apiKey
      ? "Listening from Soap Bubbles..."
      : "Add your OpenAI API key under Your GPT first so Soap Bubbles can answer back.",
    createdAt: new Date().toISOString(),
    pending: Boolean(settings.apiKey)
  };
  serverThread.messages.push(pendingMessage);
  saveServerThread();
  render();

  if (!settings.apiKey) return;

  try {
    const answer = await askOpenAI(buildServerInput(text));
    pendingMessage.text = answer || "I did not get text back. Try again in a moment.";
  } catch (error) {
    pendingMessage.text = `Soap Bubbles request failed: ${error.message}`;
  } finally {
    pendingMessage.pending = false;
    pendingMessage.createdAt = new Date().toISOString();
    saveServerThread();
    render();
  }
});

document.querySelectorAll("[data-build]").forEach((button) => {
  button.addEventListener("click", () => {
    const bubble = getSelected();
    if (!bubble) return;
    const linked = bubble.links
      .map((id) => state.bubbles.find((item) => item.id === id)?.content)
      .filter(Boolean);
    const latest = bubble.messages.at(-1)?.text;

    if (button.dataset.build === "summary") {
      elements.buildOutput.textContent = `This is about: ${bubble.content}${linked.length ? ` It connects to ${linked.length} other thought${linked.length === 1 ? "" : "s"}.` : ""}`;
    }
    if (button.dataset.build === "next") {
      elements.buildOutput.textContent = latest
        ? `Next step: turn "${latest}" into one concrete action you can do in the next 20 minutes.`
        : "Next step: add one expansion sentence, then decide whether this is a note, question, decision, or seed.";
    }
    if (button.dataset.build === "question") {
      elements.buildOutput.textContent = `Better question: What would become clearer if I followed "${shorten(bubble.content, 54)}" one layer deeper?`;
    }
  });
});

elements.saveVault.addEventListener("click", async () => {
  const result = await saveVaultNow();
  elements.buildOutput.textContent = result.ok
    ? `Vault saved: ${result.dataFile}`
    : `Vault save failed: ${result.error}`;
});

elements.quickSaveVault.addEventListener("click", async () => {
  const result = await saveVaultNow();
  elements.vaultBannerText.textContent = result.ok
    ? `Saved ${state.bubbles.length} bubble${state.bubbles.length === 1 ? "" : "s"} to disk.`
    : `Save failed: ${result.error}`;
});

elements.downloadVault.addEventListener("click", () => {
  downloadState("vault");
});

elements.exportJson.addEventListener("click", () => {
  downloadState("export");
});
elements.importJson.addEventListener("click", () => {
  elements.importFile.click();
});

elements.importFile.addEventListener("change", async () => {
  const file = elements.importFile.files[0];
  if (!file) return;

  try {
    const text = await file.text();
    const parsed = JSON.parse(text);
    const bubbles = Array.isArray(parsed) ? parsed : parsed.bubbles;
    if (!Array.isArray(bubbles)) throw new Error("No bubbles were found in that backup.");
    state = {
      bubbles: normalizeBubbles(bubbles),
      selectedId: parsed.selectedId || bubbles[0]?.id || null
    };
    selectedId = state.selectedId;
    saveAndRender();
    elements.buildOutput.textContent = "Backup imported into local storage.";
  } catch (error) {
    elements.buildOutput.textContent = `Import failed: ${error.message}`;
  } finally {
    elements.importFile.value = "";
  }
});

elements.saveSettings.addEventListener("click", () => {
  settings = {
    apiKey: elements.apiKey.value.trim(),
    model: elements.modelName.value.trim() || "gpt-5.2",
    guidePrompt: elements.guidePrompt.value.trim() || defaultGuidePrompt
  };
  saveSettings();
  hydrateSettings();
  elements.buildOutput.textContent = "GPT settings saved locally on this Mac.";
});

elements.clearAll.addEventListener("click", () => {
  if (!confirm("Clear every bubble from this browser?")) return;
  state = { bubbles: [], selectedId: null };
  selectedId = null;
  saveAndRender();
});

elements.autoArrange.addEventListener("click", () => {
  const total = state.bubbles.length || 1;
  state.bubbles.forEach((bubble, index) => {
    const angle = (Math.PI * 2 * index) / total - Math.PI / 2;
    const radius = total < 4 ? 18 : 28;
    bubble.x = 50 + Math.cos(angle) * radius;
    bubble.y = 50 + Math.sin(angle) * radius;
  });
  saveAndRender();
});

window.addEventListener("pointermove", (event) => {
  if (!dragging) return;
  const rect = elements.map.getBoundingClientRect();
  const bubble = state.bubbles.find((item) => item.id === dragging.id);
  if (!bubble) return;

  const nextX = ((event.clientX - rect.left - dragging.offsetX) / rect.width) * 100;
  const nextY = ((event.clientY - rect.top - dragging.offsetY) / rect.height) * 100;
  bubble.x = Math.max(2, Math.min(88, nextX));
  bubble.y = Math.max(2, Math.min(86, nextY));
  renderMap();
});

window.addEventListener("pointerup", () => {
  if (!dragging) return;
  dragging = null;
  save();
});

function render(options = {}) {
  renderClientSurface();
  renderMobileView();
  renderServerThread();
  elements.count.textContent = state.bubbles.length;
  elements.vaultStatus.textContent = vaultAvailable ? "Vault on" : "Browser";
  elements.vaultMode.textContent = vaultAvailable ? "Disk vault active" : "Browser fallback";
  elements.vaultDetail.textContent = vaultAvailable
    ? `Last saved ${vaultInfo.savedAt ? formatTime(vaultInfo.savedAt) : "just now"}. ${vaultInfo.regularBackupCount} regular backup${vaultInfo.regularBackupCount === 1 ? "" : "s"} and ${vaultInfo.preRestoreBackupCount} pre-restore backup${vaultInfo.preRestoreBackupCount === 1 ? "" : "s"} on disk.`
    : "Start the local vault server to save real files on this Mac.";
  elements.vaultBannerText.textContent = vaultAvailable
    ? `Protected on this Mac${vaultInfo.savedAt ? ` - ${formatTime(vaultInfo.savedAt)}` : ""}.`
    : "Browser only until the vault server connects.";
  elements.empty.classList.toggle("hidden", state.bubbles.length > 0);
  renderList();
  renderMap();
  renderDetail(options);
  renderBackups();
}

function renderMobileView() {
  const isMobile = window.matchMedia("(max-width: 760px)").matches;
  document.body.dataset.mobileView = isMobile ? mobileView : "all";
  elements.mobileNavButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.mobileView === mobileView);
  });
}

function renderServerThread() {
  const bubble = getSelected();
  const selectedDocument = getSelectedServerDocument();
  const messageCount = serverThread.messages.filter((message) => !message.pending).length;
  const latestWaitingMessage = getLatestNeedsUserMessage();
  elements.serverCount.textContent = serverThreadAvailable ? `${messageCount} live` : `${messageCount} local`;
  elements.serverSubtitle.textContent = bubble
    ? `Talk inside the world of the selected thinking bubble, not outside it.${serverThreadAvailable ? ` This lane is now living on Soap Server${serverThreadSyncAt ? `, last synced ${formatTime(serverThreadSyncAt)}` : ""}.` : ""}`
    : serverThreadAvailable
      ? `A private Soap Bubbles lane living on Soap Server${serverThreadSyncAt ? `, last synced ${formatTime(serverThreadSyncAt)}` : ""}.`
      : "A private Soap Bubbles lane for the future Ubox-first setup.";
  elements.serverContext.textContent = bubble
    ? `${bubble.type}: ${shorten(bubble.content, 120)}`
    : "No bubble is in focus yet. Pick one to let the conversation lean on it.";
  elements.serverDocCount.textContent = `${serverThread.documents.length}`;
  elements.serverDocSubtitle.textContent = selectedDocument
    ? `Selected source: ${shorten(selectedDocument.title, 54)}`
    : "Bring in web pages, PDFs, and EPUBs so Soap Bubbles can read with you.";
  elements.serverDocStatus.textContent = serverThreadAvailable
    ? "Soap Server can extract and share sources here across your Mac and phone."
    : "Document intake needs Soap Server to be live. Browser fallback keeps Soap Bubbles, but not the extraction.";
  elements.serverUrlIngest.disabled = !serverThreadAvailable;
  elements.serverFileInput.disabled = !serverThreadAvailable;
  elements.serverUseSelected.disabled = !bubble;
  elements.serverLiveChip.textContent = serverThreadAvailable
    ? serverThreadSyncAt
      ? `Soap Server live · synced ${formatTime(serverThreadSyncAt)}${notificationState.unreadCount ? ` · ${notificationState.unreadCount} new` : ""}`
      : `Soap Server live${notificationState.unreadCount ? ` · ${notificationState.unreadCount} new` : ""}`
    : "Soap Server unavailable · browser fallback";
  elements.serverLiveChip.className = `server-live-chip${serverThreadAvailable ? " live" : ""}`;
  elements.serverComposeStatus.textContent = serverThreadAvailable
    ? "Messages you send here are going to the shared Soap Bubbles thread on Soap Server."
    : "Soap Server is unavailable right now, so this page is falling back to local Soap Bubbles state until the server comes back.";
  elements.serverSend.textContent = serverThreadAvailable ? "Send to Soap Bubbles" : "Send Locally";
  if (document.activeElement !== elements.serverInput && elements.serverInput.value !== (serverThread.draft || "")) {
    elements.serverInput.value = serverThread.draft || "";
  }
  elements.serverNeedsYou.classList.toggle("hidden", !latestWaitingMessage);
  if (latestWaitingMessage) {
    elements.serverNeedsYouText.textContent = shorten(latestWaitingMessage.text, 160);
  }

  renderServerDocuments();
  elements.serverMessages.innerHTML = "";
  serverThread.messages.forEach((message) => {
    const item = document.createElement("div");
    item.className = `server-message ${message.role}${message.pending ? " pending" : ""}${message.needsUser ? " needs-user" : ""}`;
    item.innerHTML = `<strong>${message.role === "assistant" ? "Soap Bubbles" : "You"}</strong>${escapeHtml(message.text)}<time>${formatDate(message.createdAt)}</time>`;
    elements.serverMessages.append(item);
  });
}

function renderServerDocuments() {
  elements.serverDocuments.innerHTML = "";
  if (!serverThread.documents.length) {
    const empty = document.createElement("div");
    empty.className = "server-document-empty";
    empty.textContent = "No sources are loaded yet. Drop in a PDF, EPUB, or web page and it will start living here.";
    elements.serverDocuments.append(empty);
    return;
  }

  serverThread.documents
    .slice()
    .sort((left, right) => right.createdAt.localeCompare(left.createdAt))
    .forEach((documentRecord) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `server-document${serverThread.selectedDocumentId === documentRecord.id ? " active" : ""}`;
      button.innerHTML = `
        <strong>${escapeHtml(shorten(documentRecord.title, 54))}</strong>
        <span>${escapeHtml(`${documentRecord.sourceType} · ${shorten(documentRecord.sourceLabel, 56)}`)}</span>
        <p>${escapeHtml(shorten(documentRecord.excerpt || "No excerpt yet.", 160))}</p>
      `;
      button.addEventListener("click", () => {
        serverThread.selectedDocumentId = documentRecord.id;
        saveServerThread();
        render();
      });
      elements.serverDocuments.append(button);
    });
}

function renderClientSurface() {
  const origin = window.location.origin;
  const hostname = window.location.hostname;
  const protocol = window.location.protocol;
  const isLocalOnly = ["127.0.0.1", "localhost"].includes(hostname);
  const isNetworkHost = !isLocalOnly && Boolean(hostname);
  const isFilePreview = protocol === "file:";
  const isStandalone = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;
  const isiPhone = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const notificationSupported = "Notification" in window;
  const notificationPermission = notificationSupported ? Notification.permission : "unsupported";
  const liveServerUrl = `http://192.168.4.78:5173`;

  elements.clientModeBanner.hidden = !isFilePreview;
  elements.clientModeActions.hidden = !isFilePreview;
  elements.clientLiveLink.href = liveServerUrl;
  elements.clientModeBanner.textContent = isFilePreview
    ? "You opened the local BubblePath preview. For real shared Soap Bubbles chat, use the live Soap Server URL instead."
    : "This page is connected to a real server path.";
  elements.clientOrigin.textContent = origin;
  elements.clientReach.textContent = isFilePreview
    ? "This file preview cannot reach Soap Server APIs, so Soap Bubbles falls back to local browser-only state here."
    : isLocalOnly
    ? "This run is local to this machine right now. Put the server on the Ubox to reach it from your phone too."
    : `This run is network-visible at ${origin}, so your Mac and phone can use the same browser surface while the server stays up.`;
  elements.clientHome.textContent = isFilePreview
    ? `Use the live Soap Server page at ${liveServerUrl} when you want the real shared chat lane.`
    : isNetworkHost
    ? "This page is already running from a shared host, which is the right shape for the future Ubox-first setup."
    : "Next step: run this browser client on the Ubox with the network start mode so the page can become the shared front door.";
  elements.clientInstall.textContent = isStandalone
    ? "BubblePath is already running like an installed app on this device."
    : deferredInstallPrompt
      ? "This device can install BubblePath like an app from the browser."
      : isiPhone
        ? "On iPhone, use Share and then Add to Home Screen so BubblePath feels more like a real app."
        : "Install support depends on the browser, but this page is now set up to behave more like an app.";
  elements.clientNotify.textContent = notificationPermission === "granted"
    ? "This browser can already alert you when Soap Bubbles needs your attention."
    : notificationPermission === "denied"
      ? "Alerts are blocked in this browser right now, so Soap Bubbles cannot nudge you here yet."
      : notificationSupported
        ? "This browser can ask for alert permission, which is the first step toward real Soap Bubbles notifications."
        : "This browser does not expose notification support here, so we will need another tap-on-the-shoulder path.";
  elements.notifyPermission.disabled = !notificationSupported || notificationPermission === "granted";
  elements.notifyPermission.textContent = notificationPermission === "granted"
    ? "Alerts Ready"
    : notificationPermission === "denied"
      ? "Alerts Blocked"
      : "Turn On Alerts";
}

function renderList() {
  elements.list.innerHTML = "";
  state.bubbles.forEach((bubble) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `bubble-item${bubble.id === selectedId ? " active" : ""}`;
    button.innerHTML = `<strong>${escapeHtml(shorten(bubble.content, 92))}</strong><span>${bubble.type} - ${formatDate(bubble.createdAt)}</span>`;
    button.addEventListener("click", () => {
      selectedId = bubble.id;
      saveAndRender();
    });
    elements.list.append(button);
  });
}

function renderMap() {
  elements.map.querySelectorAll(".bubble-node").forEach((node) => node.remove());

  state.bubbles.forEach((bubble) => {
    const node = document.createElement("button");
    node.type = "button";
    node.className = `bubble-node${bubble.id === selectedId ? " active" : ""}`;
    node.style.left = `${bubble.x}%`;
    node.style.top = `${bubble.y}%`;
    node.style.setProperty("--node-color", colors[bubble.type] || colors.thought);
    node.innerHTML = `<span>${escapeHtml(shorten(bubble.content, 90))}</span>`;
    node.addEventListener("click", () => {
      selectedId = bubble.id;
      saveAndRender();
    });
    node.addEventListener("pointerdown", (event) => {
      const rect = node.getBoundingClientRect();
      dragging = {
        id: bubble.id,
        offsetX: event.clientX - rect.left,
        offsetY: event.clientY - rect.top
      };
      node.setPointerCapture(event.pointerId);
    });
    elements.map.append(node);
  });

  renderLinks();
}

function renderLinks() {
  const rect = elements.map.getBoundingClientRect();
  elements.links.setAttribute("viewBox", `0 0 ${rect.width || 800} ${rect.height || 620}`);
  elements.links.innerHTML = "";
  const drawn = new Set();

  state.bubbles.forEach((bubble) => {
    bubble.links.forEach((targetId) => {
      const target = state.bubbles.find((item) => item.id === targetId);
      if (!target) return;
      const key = [bubble.id, target.id].sort().join(":");
      if (drawn.has(key)) return;
      drawn.add(key);

      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", `${(bubble.x / 100) * rect.width + 66}`);
      line.setAttribute("y1", `${(bubble.y / 100) * rect.height + 66}`);
      line.setAttribute("x2", `${(target.x / 100) * rect.width + 66}`);
      line.setAttribute("y2", `${(target.y / 100) * rect.height + 66}`);
      line.setAttribute("stroke", "rgba(37, 77, 60, 0.32)");
      line.setAttribute("stroke-width", "3");
      line.setAttribute("stroke-linecap", "round");
      elements.links.append(line);
    });
  });
}

function renderDetail(options = {}) {
  const bubble = getSelected();
  elements.detailEmpty.classList.toggle("hidden", Boolean(bubble));
  elements.detailView.classList.toggle("hidden", !bubble);
  if (!bubble) return;

  elements.detailType.textContent = bubble.type;
  if (document.activeElement !== elements.detailContent || !options.keepFocus) {
    elements.detailContent.value = bubble.content;
  }
  elements.detailMeta.textContent = `Created ${formatDate(bubble.createdAt)} - ${bubble.links.length} connection${bubble.links.length === 1 ? "" : "s"}`;
  elements.messageCount.textContent = bubble.messages.length;

  elements.linkSelect.innerHTML = "";
  state.bubbles
    .filter((item) => item.id !== bubble.id && !bubble.links.includes(item.id))
    .forEach((item) => {
      const option = document.createElement("option");
      option.value = item.id;
      option.textContent = shorten(item.content, 44);
      elements.linkSelect.append(option);
    });
  elements.linkBubble.disabled = elements.linkSelect.options.length === 0;

  elements.linkedList.innerHTML = "";
  bubble.links.forEach((id) => {
    const linked = state.bubbles.find((item) => item.id === id);
    if (!linked) return;
    const chip = document.createElement("span");
    chip.className = "linked-chip";
    chip.textContent = shorten(linked.content, 34);
    elements.linkedList.append(chip);
  });

  elements.messages.innerHTML = "";
  bubble.messages.forEach((message) => {
    const item = document.createElement("div");
    const role = message.role || "note";
    item.className = `message ${role}`;
    item.innerHTML = `<strong>${roleLabel(role)}</strong>${escapeHtml(message.text)}<time>${formatDate(message.createdAt)}</time>`;
    elements.messages.append(item);
  });
}

async function askOpenAI(input) {
  const body = {
    model: settings.model || "gpt-5.2",
    instructions: settings.guidePrompt || defaultGuidePrompt,
    input,
    truncation: "auto"
  };

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${settings.apiKey}`
    },
    body: JSON.stringify(body)
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = data.error?.message || `${response.status} ${response.statusText}`;
    throw new Error(message);
  }
  return extractOutputText(data);
}

function buildModelInput(bubble) {
  const linked = bubble.links
    .map((id) => state.bubbles.find((item) => item.id === id))
    .filter(Boolean)
    .map((item) => `- ${item.type}: ${item.content}`)
    .join("\n");

  const context = [
    `Current bubble type: ${bubble.type}`,
    `Current bubble content: ${bubble.content}`,
    linked ? `Connected bubbles:\n${linked}` : "Connected bubbles: none yet"
  ].join("\n\n");

  const conversation = bubble.messages
    .filter((message) => ["user", "assistant"].includes(message.role))
    .filter((message) => !message.pending)
    .slice(-20)
    .map((message) => ({
      role: message.role,
      content: message.text
    }));

  return [
    {
      role: "user",
      content: `Use this BubblePath context while answering.\n\n${context}`
    },
    ...conversation
  ];
}

function buildServerInput(text) {
  const selectedBubble = getSelected();
  const selectedDocument = getSelectedServerDocument();
  const recentBubbleContext = state.bubbles
    .slice(0, 5)
    .map((bubble) => `- ${bubble.type}: ${bubble.content}`)
    .join("\n");
  const selectedContext = selectedBubble
    ? [
        `Selected bubble type: ${selectedBubble.type}`,
        `Selected bubble content: ${selectedBubble.content}`,
        selectedBubble.links.length
          ? `Selected bubble links:\n${selectedBubble.links
              .map((id) => state.bubbles.find((bubble) => bubble.id === id))
              .filter(Boolean)
              .map((bubble) => `- ${bubble.type}: ${bubble.content}`)
              .join("\n")}`
          : "Selected bubble links: none yet"
      ].join("\n\n")
    : "Selected bubble: none";
  const documentContext = selectedDocument
    ? [
        `Selected source title: ${selectedDocument.title}`,
        `Selected source kind: ${selectedDocument.sourceType}`,
        `Selected source label: ${selectedDocument.sourceLabel}`,
        `Selected source excerpt: ${selectedDocument.excerpt || "No excerpt yet."}`,
        "",
        `Selected source text:\n${selectedDocument.text.slice(0, 12000)}`
      ].join("\n")
    : "Selected source: none";

  const transcript = serverThread.messages
    .filter((message) => ["user", "assistant"].includes(message.role))
    .filter((message) => !message.pending)
    .slice(-10)
    .map((message) => ({
      role: message.role,
      content: message.text
    }));

  return [
    {
      role: "user",
      content: [
        "You are replying inside Soap Bubbles, a browser-based BubblePath conversation lane.",
        "Stay warm, grounded, and useful.",
        "When a selected bubble exists, treat it as the live thought-space context.",
        "When a selected source exists, treat it as live reading context you can quote and reason from.",
        "",
        selectedContext,
        "",
        documentContext,
        "",
        `Recent bubbles:\n${recentBubbleContext || "- none yet"}`,
        "",
        `Latest user message: ${text}`
      ].join("\n")
    },
    ...transcript
  ];
}

function extractOutputText(data) {
  if (typeof data.output_text === "string") return data.output_text.trim();
  const pieces = [];
  (data.output || []).forEach((item) => {
    (item.content || []).forEach((content) => {
      if (content.type === "output_text" && content.text) pieces.push(content.text);
    });
  });
  return pieces.join("\n").trim();
}

function saveAndRender(options) {
  state.selectedId = selectedId;
  save();
  vaultDirty = true;
  scheduleVaultSave();
  render(options);
}

function save() {
  localStorage.setItem(storageKey, JSON.stringify(state));
}

async function loadVaultState() {
  try {
    await refreshHealth();
    const response = await fetch("/api/state");
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const payload = await response.json();
    vaultAvailable = true;
    vaultInfo.dataFile = payload.dataFile || vaultInfo.dataFile;

    const vaultBubbles = normalizeBubbles(payload.data?.bubbles || []);
    const localBubbles = normalizeBubbles(state.bubbles || []);
    const shouldUseVault = payload.exists && vaultBubbles.length >= localBubbles.length && vaultBubbles.length > 0;

    if (shouldUseVault) {
      state = {
        bubbles: vaultBubbles,
        selectedId: payload.data.selectedId || vaultBubbles[0]?.id || null
      };
      selectedId = state.selectedId;
      save();
      render();
      refreshBackups();
      loadServerThreadFromServer();
      return;
    }

    if (localBubbles.length > 0) {
      await saveVaultNow();
      refreshBackups();
      render();
      loadServerThreadFromServer();
      return;
    }

    await saveVaultNow();
    refreshBackups();
    render();
    loadServerThreadFromServer();
  } catch {
    vaultAvailable = false;
    serverThreadAvailable = false;
    render();
  }
}

function scheduleVaultSave() {
  if (!vaultAvailable) return;
  clearTimeout(vaultSaveTimer);
  vaultSaveTimer = setTimeout(saveVaultNow, 450);
}

async function saveVaultNow() {
  try {
    const payload = {
      version: 1,
      selectedId,
      bubbles: state.bubbles
    };
    const response = await fetch("/api/state", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !result.ok) {
      throw new Error(result.error || `${response.status} ${response.statusText}`);
    }
    vaultAvailable = true;
    vaultInfo = {
      dataFile: result.dataFile || vaultInfo.dataFile,
      backupFile: result.backupFile || vaultInfo.backupFile,
      savedAt: new Date().toISOString(),
      backupCount: vaultInfo.backupCount + 1
    };
    vaultDirty = false;
    refreshBackups();
    showToast("Saved to this Mac");
    render();
    return { ok: true, ...result };
  } catch (error) {
    vaultAvailable = false;
    render();
    showToast("Save failed");
    return { ok: false, error: error.message };
  }
}

async function refreshBackups() {
  if (!vaultAvailable) return;
  try {
    const response = await fetch("/api/backups");
    if (!response.ok) return;
    const payload = await response.json();
    if (!payload.ok) return;
    backups = Array.isArray(payload.backups) ? payload.backups : [];
    vaultInfo.backupCount = backups.length;
    vaultInfo.regularBackupCount = backups.filter((backup) => !backup.isPreRestore).length;
    vaultInfo.preRestoreBackupCount = backups.filter((backup) => backup.isPreRestore).length;
    render();
  } catch {
    // The vault status already shows browser fallback if saves fail.
  }
}

async function refreshHealth() {
  try {
    const response = await fetch("/api/health");
    if (!response.ok) return;
    const payload = await response.json();
    if (!payload.ok) return;
    vaultAvailable = true;
    vaultInfo.dataFile = payload.dataFile || vaultInfo.dataFile;
    vaultInfo.maxRegularBackups = payload.backupPolicy?.maxRegularBackups || 0;
    vaultInfo.maxPreRestoreBackups = payload.backupPolicy?.maxPreRestoreBackups || 0;
    vaultInfo.minBackupIntervalMs = payload.backupPolicy?.minBackupIntervalMs || 0;
    vaultInfo.regularBackupCount = payload.backupCounts?.regular || vaultInfo.regularBackupCount;
    vaultInfo.preRestoreBackupCount = payload.backupCounts?.preRestore || vaultInfo.preRestoreBackupCount;
    vaultInfo.backupCount = payload.backupCounts?.total || vaultInfo.backupCount;
  } catch {
    // Keep browser fallback text if health cannot be reached.
  }
}

function renderBackups() {
  elements.backupList.innerHTML = "";
  elements.backupSummary.textContent = vaultAvailable
    ? `Keeping up to ${vaultInfo.maxRegularBackups || "?"} regular backups and ${vaultInfo.maxPreRestoreBackups || "?"} pre-restore backups. New timestamped backups are spaced by about ${Math.max(1, Math.round((vaultInfo.minBackupIntervalMs || 0) / 60000))} minute${Math.round((vaultInfo.minBackupIntervalMs || 0) / 60000) === 1 ? "" : "s"}.`
    : "Connect the local vault server to see backup policy details.";
  if (!vaultAvailable) {
    elements.backupList.textContent = "Connect the local vault server to see backups.";
    return;
  }
  if (!backups.length) {
    elements.backupList.textContent = "No disk backups yet.";
    return;
  }

  backups.slice(0, 8).forEach((backup) => {
    const item = document.createElement("div");
    item.className = "backup-item";

    const label = document.createElement("span");
    const kind = backup.isPreRestore ? "Pre-restore snapshot" : "Backup";
    label.textContent = `${kind} - ${formatDate(backup.updatedAt)} - ${Math.max(1, Math.round(backup.size / 1024))} KB`;

    const button = document.createElement("button");
    button.type = "button";
    button.textContent = "Restore";
    button.addEventListener("click", () => restoreBackup(backup.name));

    item.append(label, button);
    elements.backupList.append(item);
  });
}

async function restoreBackup(name) {
  const confirmed = confirm("Restore this backup? A pre-restore backup of the current vault will be created first.");
  if (!confirmed) return;

  try {
    const response = await fetch("/api/restore", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name })
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !result.ok) {
      throw new Error(result.error || `${response.status} ${response.statusText}`);
    }
    state = {
      bubbles: normalizeBubbles(result.data.bubbles || []),
      selectedId: result.data.selectedId || result.data.bubbles?.[0]?.id || null
    };
    selectedId = state.selectedId;
    save();
    vaultDirty = false;
    vaultInfo.savedAt = new Date().toISOString();
    await refreshBackups();
    showToast("Backup restored");
    render();
  } catch (error) {
    showToast("Restore failed");
    elements.buildOutput.textContent = `Restore failed: ${error.message}`;
  }
}

function downloadState(mode) {
  const backup = {
    app: "BubblePath",
    version: 1,
    exportedAt: new Date().toISOString(),
    selectedId,
    bubbles: state.bubbles
  };
  const blob = new Blob([JSON.stringify(backup, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = mode === "vault"
    ? `bubblepath-vault-${new Date().toISOString().slice(0, 10)}.json`
    : `bubblepath-${new Date().toISOString().slice(0, 10)}.json`;
  link.click();
  URL.revokeObjectURL(url);
}

function saveSettings() {
  localStorage.setItem(settingsKey, JSON.stringify(settings));
}

function saveServerThread() {
  localStorage.setItem(serverThreadKey, JSON.stringify(serverThread));
  serverThreadDirty = true;
  scheduleServerThreadSave();
}

function scheduleServerThreadSave() {
  if (!serverThreadAvailable) return;
  clearTimeout(serverThreadSaveTimer);
  serverThreadSaveTimer = setTimeout(saveServerThreadNow, 450);
}

async function loadServerThreadFromServer() {
  return loadServerThreadFromServerWithOptions({});
}

async function loadServerThreadFromServerWithOptions(options = {}) {
  try {
    const response = await fetch("/api/server-thread");
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const payload = await response.json();
    if (!payload.ok) throw new Error(payload.error || "Server thread load failed.");

    serverThreadAvailable = true;
    serverThreadSyncAt = payload.data?.updatedAt || payload.data?.savedAt || new Date().toISOString();
    if (Array.isArray(payload.data?.messages)) {
      const nextThread = normalizeServerThread(payload.data);

      if (!sameServerThreadContent(serverThread, nextThread)) {
        serverThread = nextThread;
        localStorage.setItem(serverThreadKey, JSON.stringify(serverThread));
        serverThreadDirty = false;
        maybeNotifyServerThreadActivity({ source: "server-sync" });
        render();
        return;
      }

      if (!options.silent) render();
      return;
    }

    if (serverThread.messages.length) {
      await saveServerThreadNow();
      return;
    }

    if (!options.silent) render();
  } catch {
    serverThreadAvailable = false;
    if (!options.silent) render();
  }
}

async function saveServerThreadNow() {
  try {
    const response = await fetch("/api/server-thread", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        draft: serverThread.draft || "",
        messages: serverThread.messages,
        documents: serverThread.documents,
        selectedDocumentId: serverThread.selectedDocumentId || ""
      })
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !result.ok) {
      throw new Error(result.error || `${response.status} ${response.statusText}`);
    }

    serverThreadAvailable = true;
    serverThreadDirty = false;
    serverThreadSyncAt = result.updatedAt || new Date().toISOString();
    maybeNotifyServerThreadActivity({ source: "local-save" });
    render();
    return { ok: true, ...result };
  } catch (error) {
    serverThreadAvailable = false;
    render();
    return { ok: false, error: error.message };
  }
}

function loadState() {
  const saved = localStorage.getItem(storageKey);
  if (!saved) return { bubbles: starterBubbles, selectedId: starterBubbles[0].id };
  try {
    const parsed = JSON.parse(saved);
    return {
      bubbles: normalizeBubbles(Array.isArray(parsed.bubbles) ? parsed.bubbles : starterBubbles),
      selectedId: parsed.selectedId || null
    };
  } catch {
    return { bubbles: starterBubbles, selectedId: starterBubbles[0].id };
  }
}

function loadSettings() {
  const saved = localStorage.getItem(settingsKey);
  if (!saved) {
    return { apiKey: "", model: "gpt-5.2", guidePrompt: defaultGuidePrompt };
  }
  try {
    const parsed = JSON.parse(saved);
    return {
      apiKey: parsed.apiKey || "",
      model: parsed.model || "gpt-5.2",
      guidePrompt: parsed.guidePrompt || defaultGuidePrompt
    };
  } catch {
    return { apiKey: "", model: "gpt-5.2", guidePrompt: defaultGuidePrompt };
  }
}

function loadServerThread() {
  const saved = localStorage.getItem(serverThreadKey);
  if (!saved) {
    return {
      messages: [
        {
          id: crypto.randomUUID(),
          role: "assistant",
          text: "Welcome to Soap Bubbles. This is the first pass at making BubblePath feel like a place where we can actually think and talk inside the same thought-space.",
          createdAt: new Date().toISOString()
        }
      ],
      draft: "",
      documents: [],
      selectedDocumentId: ""
    };
  }

  try {
    return normalizeServerThread(JSON.parse(saved));
  } catch {
    return {
      draft: "",
      messages: [],
      documents: [],
      selectedDocumentId: ""
    };
  }
}

function loadNotificationState() {
  const saved = localStorage.getItem(notificationStateKey);
  if (!saved) {
    return {
      lastNeedsUserId: "",
      lastAssistantId: "",
      lastSeenMessageId: "",
      unreadCount: 0
    };
  }

  try {
    const parsed = JSON.parse(saved);
    return {
      lastNeedsUserId: typeof parsed.lastNeedsUserId === "string" ? parsed.lastNeedsUserId : "",
      lastAssistantId: typeof parsed.lastAssistantId === "string" ? parsed.lastAssistantId : "",
      lastSeenMessageId: typeof parsed.lastSeenMessageId === "string" ? parsed.lastSeenMessageId : "",
      unreadCount: Number.isFinite(parsed.unreadCount) ? Math.max(0, parsed.unreadCount) : 0
    };
  } catch {
    return {
      lastNeedsUserId: "",
      lastAssistantId: "",
      lastSeenMessageId: "",
      unreadCount: 0
    };
  }
}

function saveNotificationState() {
  localStorage.setItem(notificationStateKey, JSON.stringify(notificationState));
}

function primeNotificationState() {
  const latestNeedsUser = getLatestNeedsUserMessage();
  const latestAssistant = getLatestAssistantMessage();
  const latestMessage = getLatestServerMessage();
  notificationState.lastNeedsUserId = latestNeedsUser?.id || notificationState.lastNeedsUserId || "";
  notificationState.lastAssistantId = latestAssistant?.id || notificationState.lastAssistantId || "";
  notificationState.lastSeenMessageId = latestMessage?.id || notificationState.lastSeenMessageId || "";
  notificationState.unreadCount = 0;
  saveNotificationState();
}

function getLatestNeedsUserMessage() {
  return serverThread.messages.filter((message) => message.needsUser && !message.pending).at(-1) || null;
}

function getLatestAssistantMessage() {
  return serverThread.messages.filter((message) => message.role === "assistant" && !message.pending).at(-1) || null;
}

function getLatestServerMessage() {
  return serverThread.messages.filter((message) => !message.pending).at(-1) || null;
}

function shouldSendBrowserNotification() {
  if (!("Notification" in window)) return false;
  if (Notification.permission !== "granted") return false;
  return document.visibilityState === "hidden" || !document.hasFocus();
}

function shouldTrackUnreadInBackground() {
  return document.visibilityState === "hidden" || !document.hasFocus();
}

function markServerThreadSeen() {
  const latestMessage = getLatestServerMessage();
  if (!latestMessage) return;
  notificationState.lastSeenMessageId = latestMessage.id;
  notificationState.unreadCount = 0;
  saveNotificationState();
}

function maybeNotifyServerThreadActivity({ source }) {
  const latestNeedsUser = getLatestNeedsUserMessage();
  const latestAssistant = getLatestAssistantMessage();
  const latestMessage = getLatestServerMessage();

  if (latestMessage?.id && latestMessage.id !== notificationState.lastSeenMessageId) {
    if (shouldTrackUnreadInBackground()) {
      notificationState.unreadCount += 1;
    } else {
      notificationState.lastSeenMessageId = latestMessage.id;
      notificationState.unreadCount = 0;
    }
    saveNotificationState();
  }

  if (latestNeedsUser?.id && latestNeedsUser.id !== notificationState.lastNeedsUserId) {
    notificationState.lastNeedsUserId = latestNeedsUser.id;
    saveNotificationState();
    if (shouldSendBrowserNotification()) {
      new Notification("Soap Bubbles needs you", {
        body: shorten(latestNeedsUser.text, 140),
        tag: `soap-bubbles-needs-you-${latestNeedsUser.id}`
      });
    }
    return;
  }

  if (
    source === "server-sync" &&
    latestAssistant?.id &&
    latestAssistant.id !== notificationState.lastAssistantId
  ) {
    notificationState.lastAssistantId = latestAssistant.id;
    saveNotificationState();
    if (shouldSendBrowserNotification()) {
      new Notification("Soap Bubbles replied", {
        body: shorten(latestAssistant.text, 140),
        tag: `soap-bubbles-reply-${latestAssistant.id}`
      });
    }
  }
}

function sameServerThreadContent(left, right) {
  return JSON.stringify({
    draft: left.draft || "",
    messages: left.messages || [],
    documents: left.documents || [],
    selectedDocumentId: left.selectedDocumentId || ""
  }) === JSON.stringify({
    draft: right.draft || "",
    messages: right.messages || [],
    documents: right.documents || [],
    selectedDocumentId: right.selectedDocumentId || ""
  });
}

function normalizeServerThread(parsed) {
  return {
    draft: typeof parsed.draft === "string" ? parsed.draft : "",
    messages: Array.isArray(parsed.messages)
      ? parsed.messages.map((message) => ({
          ...message,
          role: message.role || "assistant"
        }))
      : [],
    documents: Array.isArray(parsed.documents)
      ? parsed.documents.map((documentRecord) => ({
          id: documentRecord.id || crypto.randomUUID(),
          title: documentRecord.title || "Untitled source",
          sourceType: documentRecord.sourceType || "document",
          sourceLabel: documentRecord.sourceLabel || documentRecord.title || "Untitled source",
          createdAt: documentRecord.createdAt || new Date().toISOString(),
          excerpt: documentRecord.excerpt || "",
          text: documentRecord.text || ""
        }))
      : [],
    selectedDocumentId: typeof parsed.selectedDocumentId === "string" ? parsed.selectedDocumentId : ""
  };
}

function getSelectedServerDocument() {
  return serverThread.documents.find((documentRecord) => documentRecord.id === serverThread.selectedDocumentId) || null;
}

async function ingestServerFile(file) {
  if (!serverThreadAvailable) {
    render();
    return;
  }

  elements.serverDocStatus.textContent = `Soap Server is reading ${file.name}...`;
  const contentBase64 = await fileToBase64(file);
  const response = await fetch("/api/ingest-document", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      mode: "upload",
      fileName: file.name,
      mimeType: file.type,
      contentBase64
    })
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.ok || !payload.document) {
    throw new Error(payload.error || `${response.status} ${response.statusText}`);
  }
  commitIngestedDocument(payload.document);
}

async function ingestServerUrl(sourceUrl) {
  if (!serverThreadAvailable) {
    render();
    return;
  }

  elements.serverDocStatus.textContent = `Soap Server is fetching ${sourceUrl}...`;
  const response = await fetch("/api/ingest-document", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      mode: "url",
      url: sourceUrl
    })
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.ok || !payload.document) {
    throw new Error(payload.error || `${response.status} ${response.statusText}`);
  }
  commitIngestedDocument(payload.document);
  elements.serverUrlInput.value = "";
}

function commitIngestedDocument(documentRecord) {
  serverThread.documents = [documentRecord, ...serverThread.documents.filter((item) => item.id !== documentRecord.id)].slice(0, 12);
  serverThread.selectedDocumentId = documentRecord.id;
  serverThread.messages.push({
    id: crypto.randomUUID(),
    role: "assistant",
    text: `Loaded ${documentRecord.sourceType} source "${documentRecord.title}" into Soap Bubbles. You can ask me about it now, and that source will travel with the shared thread.`,
    createdAt: new Date().toISOString()
  });
  saveServerThread();
  render();
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || "");
      const commaIndex = result.indexOf(",");
      resolve(commaIndex >= 0 ? result.slice(commaIndex + 1) : result);
    };
    reader.onerror = () => reject(reader.error || new Error("File read failed."));
    reader.readAsDataURL(file);
  });
}

function hydrateSettings() {
  elements.apiKey.value = settings.apiKey || "";
  elements.modelName.value = settings.model || "gpt-5.2";
  elements.guidePrompt.value = settings.guidePrompt || defaultGuidePrompt;
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return;
  navigator.serviceWorker.register("/service-worker.js").catch(() => {});
}

function loadMobileView() {
  const saved = localStorage.getItem("bubblepath.mobileView");
  return ["soap", "capture", "path"].includes(saved) ? saved : "soap";
}

function saveMobileView() {
  localStorage.setItem("bubblepath.mobileView", mobileView);
}

function syncMobileViewFromHash() {
  const hash = window.location.hash.replace("#", "");
  const nextView = hash === "soap-bubbles"
    ? "soap"
    : ["soap", "capture", "path"].includes(hash)
      ? hash
      : null;
  if (nextView) {
    mobileView = nextView;
    saveMobileView();
  }
}

function updateHashForMobileView() {
  const nextHash = mobileView === "soap" ? "soap-bubbles" : mobileView;
  if (window.location.hash.replace("#", "") !== nextHash) {
    history.replaceState(null, "", `#${nextHash}`);
  }
}

function normalizeBubbles(bubbles) {
  return bubbles.map((bubble) => ({
    ...bubble,
    links: Array.isArray(bubble.links) ? bubble.links : [],
    messages: Array.isArray(bubble.messages)
      ? bubble.messages.map((message) => ({
          ...message,
          role: message.role || "note"
        }))
      : []
  }));
}

function getSelected() {
  return state.bubbles.find((bubble) => bubble.id === selectedId);
}

function shorten(text, max) {
  return text.length > max ? `${text.slice(0, max - 3)}...` : text;
}

function roleLabel(role) {
  if (role === "assistant") return "GPT";
  if (role === "user") return "You";
  return "Note";
}

function showToast(message) {
  elements.saveToast.textContent = message;
  elements.saveToast.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    elements.saveToast.classList.add("hidden");
  }, 1800);
}

function formatTime(date) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit"
  }).format(new Date(date));
}

function formatDate(date) {
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit"
  }).format(new Date(date));
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
