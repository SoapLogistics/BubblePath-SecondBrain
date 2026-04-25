#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/srv/bubblepath/repos/bubblepath"
ENSURE_SCRIPT="$APP_ROOT/scripts/server/ensure-bubblepath-web.sh"
CRON_LOG="/srv/bubblepath/logs/bubblepath-web-cron.log"

TMP_CRON="$(mktemp)"
trap 'rm -f "$TMP_CRON"' EXIT

crontab -l 2>/dev/null | rg -v "ensure-bubblepath-web\.sh" >"$TMP_CRON" || true
cat >>"$TMP_CRON" <<EOF
@reboot /bin/bash -lc '$ENSURE_SCRIPT >> "$CRON_LOG" 2>&1'
* * * * * /bin/bash -lc '$ENSURE_SCRIPT >> "$CRON_LOG" 2>&1'
EOF

crontab "$TMP_CRON"
