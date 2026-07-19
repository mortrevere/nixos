# black

`black` is the registry and backup server at `10.0.0.29`. It is a BIOS/GRUB
host: GRUB installs to `/dev/sda` and OS probing is enabled.

## Services

- CoreDNS, node exporter, public-IP metrics, and nightly `/opt` backups.
- An unauthenticated Docker Registry v2 at `http://docker.house/`.
- USB data-drive auto-mounting below `/data/<label-or-uuid>`.

Registry data persists at `/opt/docker-registry`. The shared reverse proxy
listens on port 80 and forwards every hostname to the registry's loopback port 5000. `/data/LeoBackup1` is the shared backup destination used by the server
backup jobs.

The USB mount service runs on boot and on device events; Black also retries it
every five minutes for drives that appear after boot.

## Secrets

Create `/etc/nixos/secrets/black.env` with:

```sh
BLACK_WIFI_SSID=your-ssid
BLACK_WIFI_PSK=your-wifi-password
```

## Checks

```sh
systemctl status podman-docker-registry podman-reverse-proxy mount-data-drives.timer
curl -I -H 'Host: docker.house' http://127.0.0.1/
findmnt /data
```

## Rebuild

```sh
./hacks/black.sh
```
