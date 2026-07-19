{
  pkgs,
  username,
  hostname,
  ...
}:

{
  imports = [ ./core.nix ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.${username}.extraGroups = [ "podman" ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  environment.systemPackages = with pkgs; [
    git
    htop
    podman
    docker-compose
    gh
    bat
    ccrypt
    curl
    dfc
    gocryptfs
    jq
    openssl
    yq-go
    rclone
    wget
    unzip
    tree
    slurp
    uv
    python3
  ];

}
