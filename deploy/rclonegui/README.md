# rclonegui — LoveCloud rclone Web GUI / Remote Control

This is the missing `rclonegui` unit. It stayed `configured_pending` because rclone-koofr and rclone-e2 mounts were running, but nobody shipped an `rclone rcd --rc-web-gui` container under the `rclonegui` name.

## Bring it up (Oracle sOS)

```bash
cd deploy/rclonegui
cp .env.example .env          # set RCLONE_RC_USER / RCLONE_RC_PASS
cp rclone.conf.example config/rclone.conf   # or copy the host rclone.conf
# If remotes already exist on the box:
#   mkdir -p config && cp ~/.config/rclone/rclone.conf config/rclone.conf
docker compose up -d
```

Quadlet (same host as webtop):

```bash
sudo cp rclonegui.container /etc/containers/systemd/
sudo systemctl daemon-reload
sudo systemctl start rclonegui
```

Nginx Proxy Manager / Traefik should already cover `*.shannonjlove.cloud`. Point:

| Host | Upstream |
| --- | --- |
| rclonegui.shannonjlove.cloud | Oracle `:5572` |
| files.shannonjlove.cloud | same container |

The iOS Drive Browser probes these hosts in order and stores the first one that answers `core/version`. rclonegui is configured, not pending.
