{
  kor,
  lib,
  hyraizyn,
  ...
}:
let
  inherit (kor) concatMapAttrs;
  inherit (lib) mkOverride optional optionals;
  inherit (hyraizyn) astra exAstriz;
  inherit (builtins) concatStringsSep;

  mkCriomeHostEntries =
    name: astri:
    let
      inherit (astri) criomOSName neksysIp yggAddress;
      inherit (astri.methods) isNixCache nixCacheDomain;

      mkPreNeksysHost = linkLocalIP: {
        name = linkLocalIP;
        value = [ ("wg." + criomOSName) ];
      };

      neksysHost = {
        name = neksysIp;
        value = [ criomOSName ];
      };

      preNeksysHosts = map mkPreNeksysHost astri.linkLocalIPs;

      neksysHosts = optionals (neksysIp != null) ([ neksysHost ] ++ preNeksysHosts);

      yggdrasilHost = optional (yggAddress != null) {
        name = yggAddress;
        value = [ criomOSName ] ++ (optional isNixCache nixCacheDomain);
      };

    in
    yggdrasilHost ++ neksysHosts;

in
{
  imports = [
    ./unbound.nix
    ./yggdrasil.nix
  ];

  networking = {
    hostName = astra.name;
    dhcpcd.extraConfig = "noipv4ll";
    nameservers = [
      "::1"
      "127.0.0.1"
    ];
    hosts = concatMapAttrs mkCriomeHostEntries exAstriz;
  };

  services = {
    nscd.enable = false;
  };

  system.nssModules = mkOverride 0 [ ];
}
