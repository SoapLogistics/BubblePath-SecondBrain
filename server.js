const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;
const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 5173);
const vaultDir = path.join(root, "bubblepath-vault");
const backupsDir = path.join(vaultDir, "backups");
const dataFile = path.join(vaultDir, "bubblepath-data.json");
const serverThreadFile = path.join(vaultDir, "bubblepath-server-thread.json");
const minBackupIntervalMs = 60 * 1000;
const maxRegularBackups = 24;
const maxPreRestoreBackups = 12;

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
        messages: []
      }
    });
  }

  const data = JSON.parse(fs.readFileSync(serverThreadFile, "utf8"));
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
    messages: Array.isArray(data.messages) ? data.messages : []
  };
  fs.writeFileSync(serverThreadFile, `${JSON.stringify(thread, null, 2)}\n`);

  return sendJson(res, 200, {
    ok: true,
    serverThreadFile,
    updatedAt
  });
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
      if (body.length > 1024 * 1024 * 10) {
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
