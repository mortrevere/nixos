{
  username,
  ...
}:

{
  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--operator=${username}"
      "--accept-routes=true"
      "--stateful-filtering"
    ];
  };
}
