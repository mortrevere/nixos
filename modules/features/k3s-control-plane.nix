{ pkgs, ... }:

{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"
      "--write-kubeconfig-mode=0644"
      "--tls-san=red.house"
    ];
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
  ];

  environment.shellAliases = {
    k3s-status = "systemctl status k3s --no-pager";
    k3s-logs = "journalctl -u k3s -f";
    k3s-kubectl = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl";
  };
}
