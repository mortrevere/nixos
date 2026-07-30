# blue

`blue` is the media server at `blue.house.leo.surf` (`10.0.0.30`). It uses
DHCP-managed Wi-Fi and systemd-boot with an EFI `/boot` partition.

## Services

- CoreDNS, node exporter, public-IP metrics, and nightly `/opt` backups.
- Transmission at `https://transmission.house.leo.surf/`.
- Jellyfin at `https://cinema.house.leo.surf/` with Intel `/dev/dri` hardware acceleration.
- ATV at `https://atv.house.leo.surf/` for Android TV remote control.
- A shared nginx reverse proxy on ports 80 and 443; HTTP redirects to HTTPS.

Transmission stores configuration, downloads, and watch files under
`/opt/transmission`. Jellyfin stores configuration under `/opt/jellyfin`, uses
a 4 GiB tmpfs at `/opt/jellyfin/transcodes`, and receives the Transmission
downloads directory as `/data/media`. External USB drives are mounted below
`/data/<label-or-uuid>` and provide the additional `Extreme_SSD` libraries.

Completed Transmission items are moved hourly from
`/opt/transmission/downloads/complete` to
`/data/Extreme_SSD/archives/films` once all of their contents have been
unchanged for 24 hours. The mover is defined in
`move-completed-films.sh` and will not run while the archive drive is absent.

The firewall admits HTTP/HTTPS, SSH, CoreDNS from private networks, node-exporter
scrapes from private networks, and Transmission peer traffic on TCP/UDP 51413.
Podman networking is preserved across firewall reloads; do not replace the
managed `networking.nftables.tables` configuration with a whole ruleset.

## Secrets

Create `/etc/nixos/secrets/blue.env` with:

```sh
BLUE_WIFI_SSID=your-ssid
BLUE_WIFI_PSK=your-wifi-password
JELLYFIN_ADMIN_USER=admin
JELLYFIN_ADMIN_PASSWORD=your-jellyfin-admin-password
```

The Jellyfin credentials are used only while its initial setup wizard is
incomplete.

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
systemctl status podman-atv podman-transmission podman-jellyfin podman-reverse-proxy
curl -I -H 'Host: atv.house.leo.surf' http://127.0.0.1/
curl -I -H 'Host: transmission.house.leo.surf' http://127.0.0.1/
curl -I -H 'Host: cinema.house.leo.surf' http://127.0.0.1/
curl -Ik https://atv.house.leo.surf/health
curl -Ik https://cinema.house.leo.surf/
curl -Ik https://blue-files.house.leo.surf/
```

## Rebuild

```sh
./hacks/blue.sh
```
