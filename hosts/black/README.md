# black

`black` is the registry and backup server at `black.house.leo.surf`
(`10.0.0.29`). It is a BIOS/GRUB host: GRUB installs to `/dev/sda` and OS
probing is enabled.

## Services

- CoreDNS, node exporter, public-IP metrics, and nightly `/opt` backups.
- An unauthenticated Docker Registry v2 at `https://docker.house.leo.surf/`.
- USB data-drive auto-mounting below `/data/<label-or-uuid>`.

Registry data persists at `/opt/docker-registry`. The shared reverse proxy
listens on ports 80 and 443, redirects HTTP to HTTPS, and forwards
`docker.house.leo.surf` to the registry's loopback port 5000. File Browser is
available at `black-files.house.leo.surf`.
`/data/LeoBackup1` is the shared backup destination used by the server backup
jobs.

The USB mount service runs on boot and on device events; Black also retries it
every five minutes for drives that appear after boot.

## Secrets

Create `/etc/nixos/secrets/black.env` with:

```sh
BLACK_WIFI_SSID=your-ssid
BLACK_WIFI_PSK=your-wifi-password
```

For wildcard certificate sync from Red, this host declares the public half of
`/etc/nixos/secrets/cert-sync_ed25519` for its restricted SFTP-only `cert-sync`
user:

```nix
{
  houseLeoSurf.certSyncPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBI8fr4dZLJ52Bj2i4LgExkFHuLIiyeUW+UitsGuA75 cert-sync";
}
```

## Checks

```sh
systemctl status podman-docker-registry podman-reverse-proxy mount-data-drives.timer
curl -I -H 'Host: docker.house.leo.surf' http://127.0.0.1/
curl -Ik https://docker.house.leo.surf/v2/
curl -Ik https://black-files.house.leo.surf/
findmnt /data
```

## Rebuild

```sh
./hacks/black.sh
```
