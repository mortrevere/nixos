let
  nodeNames = [
    "red"
    "blue"
    "black"
  ];

  addresses = {
    red = "10.0.0.19";
    blue = "10.0.0.30";
    black = "10.0.0.29";
  };

  applicationHosts = {
    cinema = "blue";
    docker = "black";
    grafana = "red";
    hyperion = "red";
    links = "red";
    nabu = "red";
    prometheus = "red";
    transmission = "blue";
  };
in
{
  inherit addresses applicationHosts nodeNames;

  domain = "house";

  publicResolvers = [
    "1.1.1.2"
    "1.0.0.2"
  ];

  peerAddresses =
    hostname:
    map (name: builtins.getAttr name addresses) (
      builtins.filter (name: name != hostname) nodeNames
    );
}
