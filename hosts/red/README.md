# red

`red` is the home gateway and observability server at `10.0.0.19`. It uses a
static Wi-Fi address and systemd-boot with an EFI `/boot` partition.

## Services

- CoreDNS for `*.house` names and recursive public DNS forwarding.
- Authoritative DHCP for the home LAN.
- NordVPN OpenVPN gateway for LAN IPv4 traffic, with ISP-router fallback.
- Grafana, Prometheus, links, Hyperion, and Nabu behind the shared nginx
  reverse proxy.
- Node exporter, public-IP metrics, and nightly `/opt` backup jobs.

The proxy exposes `grafana.house`, `prometheus.house`, `links.house`,
`hyperion.house`, and `nabu.house`. HTTP access is restricted to private IPv4
addresses.

## Secrets

Create `/etc/nixos/secrets/red.env` with:

```sh
RED_WIFI_SSID=your-ssid
RED_WIFI_PSK=your-wifi-password
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-grafana-admin-password
```

Create `/etc/nixos/secrets/nordvpn.auth` as root-owned mode `0600`. It must
contain the NordVPN manual-setup service username and password on separate
lines.

## DHCP, DNS, and VPN

DHCP runs only on `wlp0s20f3`, leases `10.0.0.10` through `10.0.0.254`, and
advertises Red (`10.0.0.19`) as the default IPv4 gateway. It advertises the
three CoreDNS instances at Red, Blue, and Black as resolvers. Fixed client
reservations are declared in `modules/features/dhcp-server.nix`.

CoreDNS listens on port 53 and resolves host and application names in the
`house` domain from `modules/home-lan.nix`. Other DNS requests are forwarded to
the configured public resolvers. Check a local name with:

```sh
dig @127.0.0.1 cinema.house
```

NordVPN uses the selected profile in `configuration.nix` and a stable
`tun-nord` interface. Red forwards and masquerades LAN traffic through that
tunnel. If the tunnel is unavailable, the configured rules allow internet-bound
traffic to use the physical router at `10.0.0.1`; local private destinations
are not forwarded through this fallback path.

```sh
systemctl status openvpn-nordvpn dnsmasq podman-coredns
ip -4 address show tun-nord
ip -4 route
curl -4 https://ifconfig.co
```

After changing the advertised gateway or resolver set, renew DHCP leases on
clients. To switch VPN endpoints, add the `.ovpn` profile under `nordvpn/`, add
it to `nordvpnGateway.profiles`, and change `nordvpnGateway.activeProfile`.
Profiles must contain `dev tun` and a bare `auth-user-pass` directive.

## Rebuild

```sh
./hacks/red.sh
```
