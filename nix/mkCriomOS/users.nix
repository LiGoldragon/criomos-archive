{
  hyraizyn,
  config,
  kor,
  pkgs,
  ...
}:
let
  inherit (builtins)
    filter
    mapAttrs
    attrNames
    hasAttr
    concatStringsSep
    concatMap
    ;
  inherit (kor)
    optionals
    optional
    optionalString
    mkIf
    optionalAttrs
    ;

  inherit (hyraizyn) astra exAstriz users;
  inherit (astra.methods) adminEseseitcPreCriomes;

  userNames = attrNames users;

  mkEseseitcString =
    preCriome:
    concatStringsSep " " [
      "ed25519"
      preCriome.eseseitc
    ];

  mkUser =
    attrName: user:
    let
      inherit (user) trost methods;
      inherit (user.methods) eseseitcyz hazPreCriome;

    in
    optionalAttrs (trost > 0) {
      name = user.name;

      useDefaultShell = true;
      isNormalUser = true;

      openssh.authorizedKeys.keys = eseseitcyz;

      extraGroups =
        [ "audio" ]
        ++ (optional (config.programs.sway.enable == true) "sway")
        ++ (optionals (trost >= 2) (
          [ "video" ] ++ (optional (config.networking.networkmanager.enable == true)) "networkmanager"
        ))
        ++ (optionals (trost >= 3) [
          "adbusers"
          "nixdev"
          "systemd-journal"
          "dialout"
          "plugdev"
          "storage"
          "libvirtd"
        ]);
    };

  mkUserUsers = mapAttrs mkUser users;

  rootUserAkses = {
    root = {
      openssh.authorizedKeys.keys = adminEseseitcPreCriomes;
    };
  };

in
{
  users = {
    users = mkUserUsers // rootUserAkses;
  };
}
