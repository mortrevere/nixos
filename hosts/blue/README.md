# blue

`blue` is the media server at `10.0.0.30`. It uses DHCP-managed Wi-Fi and
systemd-boot with an EFI `/boot` partition.

## Services

- CoreDNS, node exporter, public-IP metrics, and nightly `/opt` backups.
- Transmission at `http://transmission.house/`.
- Jellyfin at `http://cinema.house/` with Intel `/dev/dri` hardware acceleration.
- A shared nginx reverse proxy on port 80.

Transmission stores configuration, downloads, and watch files under
`/opt/transmission`. Jellyfin stores configuration under `/opt/jellyfin`, uses
a 4 GiB tmpfs at `/opt/jellyfin/transcodes`, and receives the Transmission
downloads directory as `/data/media`. External USB drives are mounted below
`/data/<label-or-uuid>` and provide the additional `Extreme_SSD` libraries.

The firewall admits HTTP, SSH, CoreDNS from private networks, node-exporter
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

## Checks

```sh
systemctl status podman-transmission podman-jellyfin podman-reverse-proxy
curl -I -H 'Host: transmission.house' http://127.0.0.1/
curl -I -H 'Host: cinema.house' http://127.0.0.1/
```

## Rebuild

```sh
./hacks/blue.sh
```
