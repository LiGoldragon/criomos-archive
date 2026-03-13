{
  config,
  lib,
  pkgs,
  horizon,
  ...
}:
let
  inherit (builtins)
    map
    concatStringsSep
    concatMap
    attrNames
    attrValues
    split
    head
    match
    ;
  inherit (lib) mapAttrsToList concatMapStringsSep lowPrio;
  inherit (horizon) node cluster exNodes;
  inherit (horizon.node) typeIs criomeDomainName;

  tailnetBaseDomain = "tailnet.${cluster.name}.criome";
  headscaleEnabled = config.services.headscale.enable;

  listenIPs = [
    "::1"
    "127.0.0.1"
  ];
  allowedIPs = [
    "::1"
    "127.0.0.1"
  ];

  TLSDNServers = {
    "cloudflare-dns.com" = [
      "2606:4700:4700::1111"
      "1.1.1.1"
      "2606:4700:4700::1001"
      "1.0.0.1"
    ];
    "dns.quad9.net" = [
      "2620:fe::fe"
      "9.9.9.9"
      "2620:fe::9"
      "149.112.112.112"
    ];
  };

  mkForwardServerUrls = domain: ipList: map (ip: "${ip}@853#${domain}") ipList;

  forwardServerUrls = concatMap (name: mkForwardServerUrls name TLSDNServers.${name}) (
    attrNames TLSDNServers
  );

  horizonNodes = [ node ] ++ attrValues exNodes;

  mkFqdn = name: concatStringsSep "." [ name "" ];

  mkRecord = { name, rtype, value }:
    concatStringsSep " " [
      mkFqdn name
      "IN"
      rtype
      value
    ];

  sanitizeIp = ip:
    if ip == null || ip == "" then
      null
    else
      let
        cleaned = head (split "/" ip);
      in
        if cleaned == "" then null else cleaned;

  recordTypeForIp = ip:
    if match ".*:.*" ip != null then "AAAA" else "A";

  mkAddressRecord = { name, ip }:
    let
      address = sanitizeIp ip;
    in
      if address == null then
        []
      else
        [ mkRecord { name = name; rtype = recordTypeForIp address; value = address; } ];

  mkYggRecords = entry:
    let
      address = sanitizeIp entry.yggAddress;
      alias = entry.methods.nixCacheDomain;
      aliasRecord =
        if address == null || alias == null || alias == "" then
          []
        else
          [ mkRecord { name = alias; rtype = "AAAA"; value = address; } ];
    in
    if address == null then
      []
    else
      [ mkRecord { name = entry.criomeDomainName; rtype = "AAAA"; value = address; } ] ++ aliasRecord;

  mkNodeDnsRecords = entry:
    mkAddressRecord { name = entry.criomeDomainName; ip = entry.nodeIp; } ++ mkYggRecords entry;

  localDnsRecords = concatMap mkNodeDnsRecords horizonNodes;

in
{
  services.unbound = {
    # enable = (!typeIs.edge); # bootstrap
    enable = true;
    settings = {
      server = {
        interface = listenIPs;
        do-not-query-localhost = false;
        tls-cert-bundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      local-data = localDnsRecords;
      forward-zone =
        (lib.optionals headscaleEnabled [
          {
            # Split-DNS for our headscale tailnet base domain.
            # This lets us keep `tailscale up --accept-dns=false` later.
            name = "${tailnetBaseDomain}.";
            forward-addr = [ "100.100.100.100" ];
          }
        ])
        ++ [
          {
            name = ".";
            forward-tls-upstream = true;
            forward-addr = forwardServerUrls;
          }
        ];
    };
  };

}
