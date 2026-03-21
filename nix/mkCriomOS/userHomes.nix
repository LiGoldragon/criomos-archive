{
  horizon,
  world,
  homeModules,
  criomos-lib,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (world) pkdjz;

  mkUserConfig = name: user: {
    _module.args = {
      inherit user;
    };
  };

in
{
  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit
        pkdjz
        world
        horizon
        criomos-lib
        ;
    };
    sharedModules = homeModules;
    useGlobalPkgs = true;
    users = mapAttrs mkUserConfig horizon.users;
  };
}
