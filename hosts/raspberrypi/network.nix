_: {
  networking.networkmanager = {
    enable = true;
    ensureProfiles = {
      environmentFiles = [ "/etc/nixos/secrets/pi.env" ];
      profiles.raspberrypi-wifi = {
        connection = {
          id = "raspberrypi-wifi";
          type = "wifi";
          interface-name = "wlan0";
          autoconnect = true;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "$PI_WIFI_SSID";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$PI_WIFI_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
