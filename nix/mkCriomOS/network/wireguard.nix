{
  kor,
  pkgs,
  hyraizyn,
  konstynts,
  pkdjz,
  ...
}:
let
  inherit (builtins)
    mapAttrs
    attrNames
    filter
    concatStringsSep
    ;
  inherit (kor)
    mkIf
    mapAttrsToList
    optionalAttrs
    filterAttrs
    ;
  inherit (hyraizyn) astra exAstriz;
  inherit (hyraizyn.astra.methods)
    hasWireguardPrecriad
    wireguardUntrustedProxies
    ;

  mkUntrustedProxy = untrustedProxy: {
    inherit (wireguardUntrustedProxies) publicKey endpoint;
    allowedIPs = [ "0.0.0.0/0" ];
  };

  mkUntrustedProxyIp = untrustedProxy: untrustedProxy.interfaceIp;

  untrustedProxiesPeers = map mkUntrustedProxy wireguardUntrustedProxies;

  untrustedProxiesIps = map mkUntrustedProxyIp wireguardUntrustedProxies;

  mkNeksysPeer = name: astri: {
    allowedIPs = [ astri.neksysIp ];
    publicKey = astri.wireguardPreCriome;
    endpoint = "wg.${astri.criomOSName}:51820";
  };

  criomeaizdPriNeksiz = filterAttrs (n: v: v.methods.hasWireguardPrecriad) exAstriz;

  neksysPeers = mapAttrsToList mkNeksysPeer criomeaizdPriNeksiz;

  privateKeyFile = "/etc/wireguard/privateKey";

in
{
  networking = {
    wireguard = {
      enable = true;
      interfaces = {
        wgProxies = {
          ips = untrustedProxiesIps;
          peers = untrustedProxiesPeers;
          inherit privateKeyFile;
        };

        wgNeksys = {
          ips = [ astra.neksysIp ];
          inherit privateKeyFile;
          peers = neksysPeers;
          listenPort = 51820;
        };

      };
    };
  };

}
