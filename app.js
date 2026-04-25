const storageKey = "bubblepath.v1";
const settingsKey = "bubblepath.settings.v1";
const serverThreadKey = "bubblepath.server.v1";
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

const elements = {
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
  serverSubtitle: document.querySelector("#server-subtitle"),
  serverCount: document.querySelector("#server-count"),
  serverContext: document.querySelector("#server-context"),
  serverMessages: document.querySelector("#server-messages"),
  serverForm: document.querySelector("#server-form"),
  serverInput: document.querySelector("#server-input"),
  serverUseSelected: document.querySelector("#server-use-selected")
};

hydrateSettings();
render();
loadVaultState();
setInterval(() => {
  if (vaultAvailable && vaultDirty) saveVaultNow();
  if (serverThreadAvailable && serverThreadDirty) saveServerThreadNow();
}, 10000);

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
  elements.serverInput.focus();
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

  const pendingMessage = {
    id: crypto.randomUUID(),
    role: "assistant",
    text: settings.apiKey
      ? "Listening from the Bubble Server..."
      : "Add your OpenAI API key under Your GPT first so Bubble Server can answer back.",
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
    pendingMessage.text = `Bubble Server request failed: ${error.message}`;
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

function renderServerThread() {
  const bubble = getSelected();
  elements.serverCount.textContent = serverThread.messages.filter((message) => !message.pending).length;
  elements.serverSubtitle.textContent = bubble
    ? `Talk inside the world of the selected bubble, not outside it.${serverThreadAvailable ? " This thread is now living on Soap Server." : ""}`
    : serverThreadAvailable
      ? "A shared conversation surface living on Soap Server."
      : "A shared conversation surface for the future Ubox-first setup.";
  elements.serverContext.textContent = bubble
    ? `${bubble.type}: ${shorten(bubble.content, 120)}`
    : "No bubble is in focus yet. Pick one to let the conversation lean on it.";
  elements.serverUseSelected.disabled = !bubble;

  elements.serverMessages.innerHTML = "";
  serverThread.messages.forEach((message) => {
    const item = document.createElement("div");
    item.className = `server-message ${message.role}${message.pending ? " pending" : ""}`;
    item.innerHTML = `<strong>${message.role === "assistant" ? "Bubble Server" : "You"}</strong>${escapeHtml(message.text)}<time>${formatDate(message.createdAt)}</time>`;
    elements.serverMessages.append(item);
  });
}

function renderClientSurface() {
  const origin = window.location.origin;
  const hostname = window.location.hostname;
  const isLocalOnly = ["127.0.0.1", "localhost"].includes(hostname);
  const isNetworkHost = !isLocalOnly && Boolean(hostname);

  elements.clientOrigin.textContent = origin;
  elements.clientReach.textContent = isLocalOnly
    ? "This run is local to this machine right now. Put the server on the Ubox to reach it from your phone too."
    : `This run is network-visible at ${origin}, so your Mac and phone can use the same browser surface while the server stays up.`;
  elements.clientHome.textContent = isNetworkHost
    ? "This page is already running from a shared host, which is the right shape for the future Ubox-first setup."
    : "Next step: run this browser client on the Ubox with the network start mode so the page can become the shared front door.";
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
        "You are replying inside Bubble Server, a browser-based BubblePath conversation lane.",
        "Stay warm, grounded, and useful.",
        "When a selected bubble exists, treat it as the live thought-space context.",
        "",
        selectedContext,
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
  try {
    const response = await fetch("/api/server-thread");
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const payload = await response.json();
    if (!payload.ok) throw new Error(payload.error || "Server thread load failed.");

    serverThreadAvailable = true;
    if (Array.isArray(payload.data?.messages) && payload.data.messages.length) {
      serverThread = {
        messages: payload.data.messages.map((message) => ({
          ...message,
          role: message.role || "assistant"
        }))
      };
      localStorage.setItem(serverThreadKey, JSON.stringify(serverThread));
      serverThreadDirty = false;
      render();
      return;
    }

    if (serverThread.messages.length) {
      await saveServerThreadNow();
      return;
    }

    render();
  } catch {
    serverThreadAvailable = false;
    render();
  }
}

async function saveServerThreadNow() {
  try {
    const response = await fetch("/api/server-thread", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ messages: serverThread.messages })
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !result.ok) {
      throw new Error(result.error || `${response.status} ${response.statusText}`);
    }

    serverThreadAvailable = true;
    serverThreadDirty = false;
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
          text: "Welcome to Bubble Server. This is the first pass at making BubblePath feel like a place where we can actually talk inside the thought-space.",
          createdAt: new Date().toISOString()
        }
      ]
    };
  }

  try {
    const parsed = JSON.parse(saved);
    return {
      messages: Array.isArray(parsed.messages)
        ? parsed.messages.map((message) => ({
            ...message,
            role: message.role || "assistant"
          }))
        : []
    };
  } catch {
    return {
      messages: []
    };
  }
}

function hydrateSettings() {
  elements.apiKey.value = settings.apiKey || "";
  elements.modelName.value = settings.model || "gpt-5.2";
  elements.guidePrompt.value = settings.guidePrompt || defaultGuidePrompt;
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
