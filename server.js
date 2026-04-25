const http = require("node:http");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { execFileSync } = require("node:child_process");

const root = __dirname;
const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 5173);
const vaultDir = path.join(root, "bubblepath-vault");
const backupsDir = path.join(vaultDir, "backups");
const dataFile = path.join(vaultDir, "bubblepath-data.json");
const serverThreadFile = path.join(vaultDir, "bubblepath-server-thread.json");
const ingestTmpDir = path.join(vaultDir, "ingest-tmp");
const minBackupIntervalMs = 60 * 1000;
const maxRegularBackups = 24;
const maxPreRestoreBackups = 12;
const maxBodyBytes = 1024 * 1024 * 30;

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".md": "text/markdown; charset=utf-8"
};

ensureVault();

const server = http.createServer(async (req, res) => {
  try {
    const method = req.method === "HEAD" ? "GET" : req.method;
    const url = new URL(req.url, `http://${req.headers.host}`);

    if (method === "GET" && url.pathname === "/api/health") {
      const backups = listBackupEntries();
      return sendJson(res, 200, {
        ok: true,
        vaultDir,
        dataFile,
        hasData: fs.existsSync(dataFile),
        access: getAccessInfo(),
        backupPolicy: {
          minBackupIntervalMs,
          maxRegularBackups,
          maxPreRestoreBackups
        },
        backupCounts: {
          total: backups.length,
          regular: backups.filter((entry) => !entry.isPreRestore).length,
          preRestore: backups.filter((entry) => entry.isPreRestore).length
        }
      });
    }

    if (method === "GET" && url.pathname === "/api/state") {
      return readState(res);
    }

    if (method === "GET" && url.pathname === "/api/backups") {
      return readBackups(res);
    }

    if (method === "GET" && url.pathname === "/api/server-thread") {
      return readServerThread(res);
    }

    if (method === "POST" && url.pathname === "/api/state") {
      return writeState(req, res);
    }

    if (method === "POST" && url.pathname === "/api/server-thread") {
      return writeServerThread(req, res);
    }

    if (method === "POST" && url.pathname === "/api/ingest-document") {
      return ingestDocument(req, res);
    }

    if (method === "POST" && url.pathname === "/api/restore") {
      return restoreBackup(req, res);
    }

    if (method !== "GET") {
      return sendText(res, 405, "Method not allowed");
    }

    return serveStatic(url.pathname, res);
  } catch (error) {
    return sendJson(res, 500, { ok: false, error: error.message });
  }
});

server.listen(port, host, () => {
  console.log(`BubblePath vault server running at http://${host}:${port}`);
  console.log(`Vault: ${vaultDir}`);
});

function ensureVault() {
  fs.mkdirSync(backupsDir, { recursive: true });
  fs.mkdirSync(ingestTmpDir, { recursive: true });
  const readme = path.join(vaultDir, "README.md");
  if (!fs.existsSync(readme)) {
    fs.writeFileSync(
      readme,
      [
        "# BubblePath Vault",
        "",
        "This folder stores BubblePath's local disk-backed data.",
        "",
        "- `bubblepath-data.json` is the latest saved state.",
        "- `backups/` contains timestamped snapshots.",
        "- regular backups are capped to prevent unbounded growth.",
        "- pre-restore backups are kept separately in a smaller set.",
        "- API keys are not stored in this vault.",
        ""
      ].join("\n")
    );
  }
}

function getAccessInfo() {
  const interfaces = os.networkInterfaces();
  const lanIps = Object.values(interfaces)
    .flat()
    .filter(Boolean)
    .filter((entry) => entry.family === "IPv4" && !entry.internal)
    .map((entry) => entry.address)
    .filter((address, index, list) => list.indexOf(address) === index);

  const access = {
    host,
    port,
    lanIps,
    lanUrls: lanIps.map((ip) => `http://${ip}:${port}`),
    tailscale: {
      dnsName: "",
      ip: "",
      url: ""
    }
  };

  try {
    const status = JSON.parse(execFileSync("tailscale", ["status", "--json"], { encoding: "utf8" }));
    access.tailscale.dnsName = status.Self?.DNSName || "";
    access.tailscale.ip = status.Self?.TailscaleIPs?.[0] || "";
    access.tailscale.url = access.tailscale.ip ? `http://${access.tailscale.ip}:${port}` : "";
  } catch {
    // Tailscale is optional here; keep the endpoint useful even without it.
  }

  return access;
}

function readState(res) {
  if (!fs.existsSync(dataFile)) {
    return sendJson(res, 200, { ok: true, exists: false, dataFile, data: null });
  }

  const data = JSON.parse(fs.readFileSync(dataFile, "utf8"));
  return sendJson(res, 200, { ok: true, exists: true, dataFile, data });
}

function readBackups(res) {
  const backups = listBackupEntries()
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));

  return sendJson(res, 200, { ok: true, backupsDir, backups });
}

function readServerThread(res) {
  if (!fs.existsSync(serverThreadFile)) {
    return sendJson(res, 200, {
      ok: true,
      exists: false,
      serverThreadFile,
      data: {
        app: "BubblePath",
        kind: "server-thread",
        updatedAt: "",
        draft: "",
        messages: [],
        documents: [],
        selectedDocumentId: ""
      }
    });
  }

  const data = normalizeServerThread(JSON.parse(fs.readFileSync(serverThreadFile, "utf8")));
  return sendJson(res, 200, {
    ok: true,
    exists: true,
    serverThreadFile,
    data
  });
}

async function restoreBackup(req, res) {
  const raw = await readBody(req);
  const body = JSON.parse(raw);
  const name = path.basename(String(body.name || ""));
  if (!name.endsWith(".json")) {
    return sendJson(res, 400, { ok: false, error: "Backup name must be a JSON file." });
  }

  const backupPath = path.normalize(path.join(backupsDir, name));
  if (!backupPath.startsWith(backupsDir)) {
    return sendJson(res, 400, { ok: false, error: "Backup path is invalid." });
  }
  if (!fs.existsSync(backupPath)) {
    return sendJson(res, 404, { ok: false, error: "Backup was not found." });
  }

  const data = JSON.parse(fs.readFileSync(backupPath, "utf8"));
  if (!Array.isArray(data.bubbles)) {
    return sendJson(res, 400, { ok: false, error: "Backup does not contain bubbles." });
  }

  const preRestoreName = `pre-restore-${new Date().toISOString().replaceAll(":", "-")}.json`;
  if (fs.existsSync(dataFile)) {
    fs.copyFileSync(dataFile, path.join(backupsDir, preRestoreName));
  }

  const restored = {
    ...data,
    app: "BubblePath",
    restoredAt: new Date().toISOString(),
    restoredFrom: backupPath
  };
  fs.writeFileSync(dataFile, `${JSON.stringify(restored, null, 2)}\n`);

  return sendJson(res, 200, {
    ok: true,
    dataFile,
    restoredFrom: backupPath,
    preRestoreBackup: fs.existsSync(path.join(backupsDir, preRestoreName))
      ? path.join(backupsDir, preRestoreName)
      : null,
    data: restored
  });
}

async function writeState(req, res) {
  const raw = await readBody(req);
  const data = JSON.parse(raw);
  const snapshot = {
    ...data,
    app: "BubblePath",
    savedAt: new Date().toISOString()
  };
  const body = `${JSON.stringify(snapshot, null, 2)}\n`;
  fs.writeFileSync(dataFile, body);

  const backupFile = writeBackupIfNeeded(body);

  return sendJson(res, 200, {
    ok: true,
    dataFile,
    backupFile
  });
}

async function writeServerThread(req, res) {
  const raw = await readBody(req);
  const data = JSON.parse(raw);
  const updatedAt = new Date().toISOString();
  const thread = {
    app: "BubblePath",
    kind: "server-thread",
    updatedAt,
    savedAt: updatedAt,
    draft: typeof data.draft === "string" ? data.draft : "",
    messages: Array.isArray(data.messages) ? data.messages : [],
    documents: normalizeDocuments(data.documents),
    selectedDocumentId: typeof data.selectedDocumentId === "string" ? data.selectedDocumentId : ""
  };
  fs.writeFileSync(serverThreadFile, `${JSON.stringify(thread, null, 2)}\n`);

  return sendJson(res, 200, {
    ok: true,
    serverThreadFile,
    updatedAt
  });
}

async function ingestDocument(req, res) {
  const raw = await readBody(req);
  const body = JSON.parse(raw);
  const mode = String(body.mode || "");

  if (mode === "upload") {
    const fileName = path.basename(String(body.fileName || "")).trim();
    const contentBase64 = String(body.contentBase64 || "");
    if (!fileName || !contentBase64) {
      return sendJson(res, 400, { ok: false, error: "Upload needs a file name and file content." });
    }

    const document = extractUploadedDocument({
      fileName,
      mimeType: String(body.mimeType || ""),
      contentBase64
    });
    return sendJson(res, 200, { ok: true, document });
  }

  if (mode === "url") {
    const sourceUrl = String(body.url || "").trim();
    if (!sourceUrl) {
      return sendJson(res, 400, { ok: false, error: "A web page URL is required." });
    }

    const document = await extractUrlDocument(sourceUrl);
    return sendJson(res, 200, { ok: true, document });
  }

  return sendJson(res, 400, { ok: false, error: "Unsupported document ingest mode." });
}

function writeBackupIfNeeded(body) {
  const latest = latestBackup();
  if (latest && Date.now() - latest.mtimeMs < minBackupIntervalMs) {
    return latest.path;
  }

  const backupName = `bubblepath-${new Date().toISOString().replaceAll(":", "-")}.json`;
  const backupPath = path.join(backupsDir, backupName);
  fs.writeFileSync(backupPath, body);
  pruneBackups();
  return backupPath;
}

function latestBackup() {
  const backups = listBackupEntries()
    .filter((entry) => !entry.isPreRestore)
    .map((entry) => ({
      path: entry.path,
      mtimeMs: Date.parse(entry.updatedAt)
    }))
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  return backups[0] || null;
}

function pruneBackups() {
  const entries = listBackupEntries();
  const regular = entries.filter((entry) => !entry.isPreRestore);
  const preRestore = entries.filter((entry) => entry.isPreRestore);

  removeOverflow(regular, maxRegularBackups);
  removeOverflow(preRestore, maxPreRestoreBackups);
}

function removeOverflow(entries, limit) {
  if (entries.length <= limit) return;
  entries
    .sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt))
    .slice(limit)
    .forEach((entry) => {
      if (fs.existsSync(entry.path)) {
        fs.unlinkSync(entry.path);
      }
    });
}

function listBackupEntries() {
  return fs
    .readdirSync(backupsDir)
    .map(toBackupEntry)
    .filter(Boolean);
}

function toBackupEntry(name) {
  if (!name.endsWith(".json")) return null;
  const filePath = path.join(backupsDir, name);
  const stat = fs.statSync(filePath);
  return {
    name,
    path: filePath,
    size: stat.size,
    createdAt: stat.birthtime.toISOString(),
    updatedAt: stat.mtime.toISOString(),
    isPreRestore: name.startsWith("pre-restore-")
  };
}

function serveStatic(urlPath, res) {
  const safePath = urlPath === "/" ? "/index.html" : decodeURIComponent(urlPath);
  const filePath = path.normalize(path.join(root, safePath));

  if (!filePath.startsWith(root)) {
    return sendText(res, 403, "Forbidden");
  }

  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    return sendText(res, 404, "Not found");
  }

  const ext = path.extname(filePath);
  res.writeHead(200, {
    "Content-Type": mimeTypes[ext] || "application/octet-stream",
    "Cache-Control": "no-store, max-age=0"
  });
  fs.createReadStream(filePath).pipe(res);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > maxBodyBytes) {
        req.destroy(new Error("Request body too large"));
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

function sendJson(res, status, value) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(`${JSON.stringify(value, null, 2)}\n`);
}

function sendText(res, status, value) {
  res.writeHead(status, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(value);
}

function normalizeServerThread(data) {
  return {
    app: "BubblePath",
    kind: "server-thread",
    updatedAt: typeof data.updatedAt === "string" ? data.updatedAt : "",
    savedAt: typeof data.savedAt === "string" ? data.savedAt : "",
    draft: typeof data.draft === "string" ? data.draft : "",
    messages: Array.isArray(data.messages) ? data.messages : [],
    documents: normalizeDocuments(data.documents),
    selectedDocumentId: typeof data.selectedDocumentId === "string" ? data.selectedDocumentId : ""
  };
}

function normalizeDocuments(documents) {
  return Array.isArray(documents)
    ? documents
        .filter(Boolean)
        .map((document) => ({
          id: String(document.id || crypto.randomUUID()),
          title: String(document.title || "Untitled source"),
          sourceType: String(document.sourceType || "document"),
          sourceLabel: String(document.sourceLabel || document.title || "Untitled source"),
          createdAt: typeof document.createdAt === "string" ? document.createdAt : new Date().toISOString(),
          excerpt: String(document.excerpt || ""),
          text: String(document.text || "")
        }))
    : [];
}

function extractUploadedDocument({ fileName, mimeType, contentBase64 }) {
  const extension = path.extname(fileName).toLowerCase();
  const tempBase = path.join(ingestTmpDir, `${Date.now()}-${crypto.randomUUID()}`);
  const tempPath = `${tempBase}${extension || ""}`;
  const sourceBuffer = Buffer.from(contentBase64, "base64");
  fs.writeFileSync(tempPath, sourceBuffer);

  try {
    let text = "";
    if (extension === ".pdf" || mimeType === "application/pdf") {
      text = execFileSync("pdftotext", ["-layout", "-enc", "UTF-8", tempPath, "-"], {
        encoding: "utf8",
        maxBuffer: maxBodyBytes
      });
    } else if (extension === ".epub" || mimeType === "application/epub+zip") {
      text = execFileSync("pandoc", [tempPath, "-t", "plain"], {
        encoding: "utf8",
        maxBuffer: maxBodyBytes
      });
    } else {
      text = sourceBuffer.toString("utf8");
      if (extension === ".html" || extension === ".htm" || mimeType === "text/html") {
        text = htmlToText(text);
      }
    }

    const cleanText = normalizeExtractedText(text);
    return buildDocumentRecord({
      title: path.basename(fileName, extension) || fileName,
      sourceType: extension === ".pdf"
        ? "pdf"
        : extension === ".epub"
          ? "epub"
          : extension === ".html" || extension === ".htm"
            ? "webpage"
            : "document",
      sourceLabel: fileName,
      text: cleanText
    });
  } finally {
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
  }
}

async function extractUrlDocument(sourceUrl) {
  let url;
  try {
    url = new URL(sourceUrl);
  } catch {
    throw new Error("That URL does not look valid yet.");
  }

  if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error("Only http and https web pages are supported right now.");
  }

  const response = await fetch(url, {
    headers: {
      "User-Agent": "BubblePath Soap Server"
    }
  });
  if (!response.ok) {
    throw new Error(`Page fetch failed: ${response.status} ${response.statusText}`);
  }

  const html = await response.text();
  const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  const title = titleMatch ? decodeHtmlEntities(titleMatch[1].trim()) : url.hostname;
  const text = normalizeExtractedText(htmlToText(html));

  return buildDocumentRecord({
    title: title || url.hostname,
    sourceType: "webpage",
    sourceLabel: url.toString(),
    text
  });
}

function buildDocumentRecord({ title, sourceType, sourceLabel, text }) {
  return {
    id: crypto.randomUUID(),
    title: title || "Untitled source",
    sourceType,
    sourceLabel,
    createdAt: new Date().toISOString(),
    excerpt: buildExcerpt(text),
    text
  };
}

function buildExcerpt(text) {
  return text
    .slice(0, 360)
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeExtractedText(text) {
  return String(text || "")
    .replace(/\u0000/g, "")
    .replace(/\r/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function htmlToText(html) {
  return decodeHtmlEntities(
    String(html || "")
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
      .replace(/<\/(p|div|section|article|li|h1|h2|h3|h4|h5|h6|tr)>/gi, "\n")
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<[^>]+>/g, " ")
  );
}

function decodeHtmlEntities(text) {
  return String(text || "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}
