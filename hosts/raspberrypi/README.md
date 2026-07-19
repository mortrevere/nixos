# Raspberry Pi kiosk

The host is a Raspberry Pi 4 kiosk at `pi@10.0.0.100`. Do not access or deploy
to any other host while working on this profile.

Create `/etc/nixos/secrets/pi.env` on the Pi before activating this profile:

```sh
PI_WIFI_SSID=your-ssid
PI_WIFI_PSK=your-wifi-password
```

The file must be owned by root and mode `0600`. It is deliberately not stored
in this repository or in the Nix store.
