# red

`red` is the home gateway and observability server at `red.house.leo.surf`
(`10.0.0.19`). It uses a static Wi-Fi address and systemd-boot with an EFI
`/boot` partition.

## Services

- CoreDNS for `*.house.leo.surf` names and recursive public DNS forwarding.
- Authoritative DHCP for the home LAN.
- NordVPN OpenVPN gateway for LAN IPv4 traffic, with ISP-router fallback.
- Grafana, Prometheus, links, Hyperion, and Nabu behind the shared nginx
  reverse proxy with HTTPS certificates issued through OVH DNS-01.
- Node exporter, public-IP metrics, and nightly `/opt` backup jobs.

The proxy exposes `grafana.house.leo.surf`, `prometheus.house.leo.surf`,
`links.house.leo.surf`, `hyperion.house.leo.surf`, and
`nabu.house.leo.surf`, and `iris.house.leo.surf`. File Browser is available at
`red-files.house.leo.surf`. HTTP redirects to HTTPS, and access is restricted
to private IPv4 addresses.

## Secrets

Create `/etc/nixos/secrets/red.env` with:

```sh
RED_WIFI_SSID=your-ssid
RED_WIFI_PSK=your-wifi-password
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-grafana-admin-password
CERTBOT_EMAIL=you@example.com
CERTBOT_OVH_APPLICATION_KEY=your-ovh-application-key
CERTBOT_OVH_APPLICATION_SECRET=your-ovh-application-secret
CERTBOT_OVH_CONSUMER_KEY=your-ovh-consumer-key
IRIS_NTFY_TOPIC=your-ntfy-topic
```

The OVH token only needs these permissions for the `leo.surf` zone:

```text
GET /domain/zone/
GET /domain/zone/leo.surf/*
PUT /domain/zone/leo.surf/*
POST /domain/zone/leo.surf/*
DELETE /domain/zone/leo.surf/*
```

Create `/etc/nixos/secrets/cert-sync_ed25519` as root-owned mode `0600`.
Blue and Black install its public key through their `houseLeoSurf.certSyncPublicKey`
host setting. The key authenticates only the restricted `cert-sync` SFTP user;
the receiving host validates and installs staged files as root before reloading
its reverse proxy.

Create `/etc/nixos/secrets/nordvpn.auth` as root-owned mode `0600`. It must
contain the NordVPN manual-setup service username and password on separate
lines.

Certbot state is kept under `/opt/certs/letsencrypt`, `/opt/certs/lib`, and
`/opt/certs/log`. The nginx-facing wildcard certificate is installed on each
server at `/opt/certs/house.leo.surf/fullchain.pem` and
`/opt/certs/house.leo.surf/privkey.pem`.

## DHCP, DNS, and VPN

DHCP runs only on `wlp0s20f3`, leases `10.0.0.10` through `10.0.0.254`, and
advertises Red (`10.0.0.19`) as the default IPv4 gateway. It advertises the
three CoreDNS instances at Red, Blue, and Black as resolvers. Fixed client
reservations are declared in `modules/features/dhcp-server.nix`.

CoreDNS listens on port 53 and resolves host and application names in the
`house` domain from `modules/home-lan.nix`. Other DNS requests are forwarded to
the configured public resolvers. Check a local name with:

```sh
dig @127.0.0.1 cinema.house.leo.surf
```

NordVPN uses the primary and fallback profiles in `configuration.nix` and a
stable `tun-nord` interface. Red forwards and masquerades LAN traffic through
that tunnel. If every configured profile fails, the watchdog tears down stale
VPN routes and leaves internet-bound traffic using the physical router at
`10.0.0.1`; local private destinations are not forwarded through this fallback
path. The watchdog only restarts or switches profiles after repeated failed
checks. Profile switches, VPN recovery, and fallback events notify Iris.

```sh
systemctl status openvpn-nordvpn nordvpn-gateway-watchdog.timer dnsmasq podman-coredns
ip -4 address show tun-nord
ip -4 route
curl -4 https://ifconfig.co
```

After changing the advertised gateway or resolver set, renew DHCP leases on
clients. To switch VPN endpoints, add the `.ovpn` profile under `nordvpn/`, add
it to `nordvpnGateway.profiles`, set `nordvpnGateway.activeProfile`, and append
fallbacks to `nordvpnGateway.fallbackProfiles`. Profiles must contain `dev tun`
and a bare `auth-user-pass` directive.

## Rebuild

```sh
./hacks/red.sh
sudo systemctl start house-leo-surf-certbot.service
sudo /nix/var/nix/profiles/system/sw/bin/certbot certificates \
  --config-dir /opt/certs/letsencrypt \
  --work-dir /opt/certs/lib \
  --logs-dir /opt/certs/log \
  --cert-name house.leo.surf
curl -Ik https://links.house.leo.surf/
```
