{
  hostname,
  pkgs,
  ...
}:

let
  textfileDirectory = "/var/lib/prometheus-node-exporter/textfile-collector";

  updatePublicIpMetrics = pkgs.writeShellApplication {
    name = "update-public-ip-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      output=${textfileDirectory}/public-ip.prom

      render_metric() {
        jq -er --arg host "${hostname}" '
          select(
            (.ip | type) == "string" and
            (.ip | length) > 0 and
            (.city | type) == "string" and
            (.city | length) > 0
          ) |
          "# HELP home_public_ip_info Current public IP and geolocated city.\n" +
          "# TYPE home_public_ip_info gauge\n" +
          "home_public_ip_info{host=\($host | @json),ip=\(.ip | @json),city=\(.city | @json)} 1"
        '
      }

      if response=$(curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --max-time 20 \
        --retry 2 \
        https://ipinfo.io/json) && metric=$(printf '%s' "$response" | render_metric); then
        :
      else
        metric=$(printf '%s\n' '{"ip":"UNREACHABLE","city":"UNKOWN"}' | render_metric)
      fi

      temporary=$(mktemp "${textfileDirectory}/.public-ip.prom.XXXXXX")
      trap 'rm -f "$temporary"' EXIT
      printf '%s\n' "$metric" > "$temporary"
      chmod 0644 "$temporary"
      mv -f "$temporary" "$output"
      trap - EXIT
    '';
  };
in
{
  services.prometheus.exporters.node = {
    enabledCollectors = [ "textfile" ];
    extraFlags = [ "--collector.textfile.directory=${textfileDirectory}" ];
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * * root ${updatePublicIpMetrics}/bin/update-public-ip-metrics"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${textfileDirectory} 0755 root root -"
  ];

  environment.systemPackages = [
    updatePublicIpMetrics
  ];
}
