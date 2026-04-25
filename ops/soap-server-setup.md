# Soap Server Web Front Door

This folder holds the live-service plumbing for the BubblePath web app.

## Included pieces

- `systemd/bubblepath-web.service`
  - user-level service for the BubblePath web server
- `../scripts/server/ensure-bubblepath-web.sh`
  - no-root keepalive launcher that restores the tmux-backed web app if it falls over
- `../scripts/server/install-bubblepath-cron.sh`
  - installs the `@reboot` and minute-based cron safety net for the keepalive script
- `nginx/bubblepath.conf`
  - reverse-proxy front door for BubblePath once root-level nginx access is available

## Current intended shape

- BubblePath Node app listens on `0.0.0.0:5173` for now so direct LAN testing keeps working
- Tailscale Serve can expose that securely inside the tailnet
- nginx can later proxy `80/443` to `127.0.0.1:5173`

## Suggested server install commands

```bash
mkdir -p ~/.config/systemd/user
cp /srv/bubblepath/repos/bubblepath/ops/systemd/bubblepath-web.service ~/.config/systemd/user/bubblepath-web.service
systemctl --user daemon-reload
systemctl --user enable --now bubblepath-web.service
/srv/bubblepath/repos/bubblepath/scripts/server/install-bubblepath-cron.sh
tailscale serve --bg 5173
```

## Notes

- The user-level `systemd` service needs `linger` enabled to survive after the last login session ends.
- Until root access is available for `loginctl enable-linger millerm`, the cron keepalive script is the no-root persistence fallback.
- Tailscale Serve must be enabled once in the Tailscale admin UI for this tailnet before `tailscale serve --bg 5173` will actually publish the BubblePath front door.

## Root-level nginx install when available

```bash
sudo cp /srv/bubblepath/repos/bubblepath/ops/nginx/bubblepath.conf /etc/nginx/sites-available/bubblepath
sudo ln -sf /etc/nginx/sites-available/bubblepath /etc/nginx/sites-enabled/bubblepath
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```
