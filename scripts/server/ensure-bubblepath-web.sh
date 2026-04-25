#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/srv/bubblepath/repos/bubblepath"
SESSION_NAME="bubblepath-web"
PORT="5173"
LOG_DIR="/srv/bubblepath/logs"

mkdir -p "$LOG_DIR"

if curl -fsS "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
  exit 0
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux kill-session -t "$SESSION_NAME" || true
fi

cd "$APP_ROOT"
tmux new-session -d -s "$SESSION_NAME" "cd '$APP_ROOT' && HOST=0.0.0.0 PORT=${PORT} /usr/bin/node server.js >> '$LOG_DIR/bubblepath-web.log' 2>> '$LOG_DIR/bubblepath-web-error.log'"

