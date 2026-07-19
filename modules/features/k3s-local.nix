{ lib, pkgs, ... }:

{
  # K3s single-node server, installed declaratively.
  services.k3s = {
    enable = true;
    role = "server";

    # Nice defaults for a lightweight local test cluster.
    extraFlags = toString [
      "--disable=traefik"
      "--write-kubeconfig-mode=0644"
    ];
  };

  # Keep the service installed but do not start it at boot.
  systemd.services.k3s.wantedBy = lib.mkForce [ ];

  # Tools you'll want on an interactive host.
  environment.systemPackages = with pkgs; [
    k3s
    kubectl
  ];

  environment.shellAliases = {
    k3s-on = "sudo systemctl start k3s";
    k3s-off = "sudo systemctl stop k3s";
    k3s-status = "systemctl status k3s --no-pager";
    k3s-logs = "journalctl -u k3s -f";
    k3s-kubectl = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl";

    # Destructive: wipes the local cluster state and recreates it on next start.
    k3s-reset = ''
      sudo systemctl stop k3s && \
      sudo rm -rf /var/lib/rancher/k3s && \
      sudo rm -f /etc/rancher/k3s/k3s.yaml
    '';
  };
}
