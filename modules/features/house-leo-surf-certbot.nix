{
  pkgs,
  ...
}:

let
  homeLan = import ../home-lan.nix;

  certName = homeLan.domain;
  certDir = "/opt/certs/${certName}";
  configDir = "/opt/certs/letsencrypt";
  workDir = "/opt/certs/lib";
  logsDir = "/opt/certs/log";
  ovhCredentials = "/opt/certs/ovh.ini";
  identityFile = "/etc/nixos/secrets/cert-sync_ed25519";
  knownHostsFile = "/opt/certs/known_hosts";

  certbot = pkgs.certbot.withPlugins (plugins: [
    plugins.certbot-dns-ovh
  ]);

  deployHook = pkgs.writeShellScript "house-leo-surf-certbot-deploy-hook" ''
    set -euo pipefail

    live_dir=${configDir}/live/${certName}

    install -d -m 0755 ${certDir}
    install -m 0644 "$live_dir/fullchain.pem" ${certDir}/fullchain.pem
    install -m 0600 "$live_dir/privkey.pem" ${certDir}/privkey.pem

    install -d -m 0755 /opt/certs
    touch ${knownHostsFile}
    chmod 0600 ${knownHostsFile}

    sftp_common=(
      -i ${identityFile}
      -o IdentitiesOnly=yes
      -o StrictHostKeyChecking=accept-new
      -o UserKnownHostsFile=${knownHostsFile}
    )

    for host in blue black; do
      case "$host" in
        blue) address=${homeLan.addresses.blue} ;;
        black) address=${homeLan.addresses.black} ;;
      esac

      remote="cert-sync@$address"

      ${pkgs.openssh}/bin/sftp "''${sftp_common[@]}" "$remote" <<EOF
-rm complete
put ${certDir}/fullchain.pem fullchain.pem.next
rename fullchain.pem.next fullchain.pem
put ${certDir}/privkey.pem privkey.pem.next
rename privkey.pem.next privkey.pem
put /dev/null complete.next
rename complete.next complete
EOF
    done

    ${pkgs.systemd}/bin/systemctl try-reload-or-restart podman-reverse-proxy.service
  '';

  certbotRun = pkgs.writeShellScript "house-leo-surf-certbot" ''
    set -euo pipefail

    for variable in CERTBOT_EMAIL CERTBOT_OVH_APPLICATION_KEY CERTBOT_OVH_APPLICATION_SECRET CERTBOT_OVH_CONSUMER_KEY; do
      if [ -z "''${!variable:-}" ]; then
        echo "$variable must be set in /etc/nixos/secrets/red.env"
        exit 1
      fi
    done

    install -d -m 0755 /opt/certs ${certDir} ${configDir} ${workDir} ${logsDir}
    {
      printf '%s\n' 'dns_ovh_endpoint = ovh-eu'
      printf 'dns_ovh_application_key = %s\n' "$CERTBOT_OVH_APPLICATION_KEY"
      printf 'dns_ovh_application_secret = %s\n' "$CERTBOT_OVH_APPLICATION_SECRET"
      printf 'dns_ovh_consumer_key = %s\n' "$CERTBOT_OVH_CONSUMER_KEY"
    } > ${ovhCredentials}
    chmod 0600 ${ovhCredentials}

    common_args=(
      --config-dir ${configDir}
      --work-dir ${workDir}
      --logs-dir ${logsDir}
      --cert-name ${certName}
      --non-interactive
    )

    if [ -s ${configDir}/live/${certName}/privkey.pem ]; then
      ${certbot}/bin/certbot renew "''${common_args[@]}"
    else
      ${certbot}/bin/certbot certonly "''${common_args[@]}" \
        --agree-tos \
        --email "$CERTBOT_EMAIL" \
        --dns-ovh \
        --dns-ovh-credentials ${ovhCredentials} \
        --dns-ovh-propagation-seconds 120 \
        -d ${certName} \
        -d "*.${certName}"
    fi

    if [ -s ${configDir}/live/${certName}/privkey.pem ]; then
      ${deployHook}
    fi
  '';
in
{
  config = {
    environment.systemPackages = [
      certbot
    ];

    systemd.tmpfiles.rules = [
      "d /opt/certs 0755 root root -"
      "d ${certDir} 0755 root root -"
      "d ${configDir} 0755 root root -"
      "d ${workDir} 0755 root root -"
      "d ${logsDir} 0755 root root -"
    ];

    systemd.services.house-leo-surf-certbot = {
      description = "Issue or renew the ${certName} wildcard certificate with OVH DNS-01";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/etc/nixos/secrets/red.env";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/etc/nixos/secrets/red.env";
        ExecStart = certbotRun;
      };
    };

    systemd.timers.house-leo-surf-certbot = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03,15:17:00";
        RandomizedDelaySec = "45m";
        Persistent = true;
      };
    };

  };
}
