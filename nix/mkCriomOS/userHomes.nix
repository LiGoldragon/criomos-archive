{
  horizon,
  world,
  homeModule,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (world) pkdjz;

  profile = {
    dark = false;
  };

  mkUserConfig = name: user: {
    _module.args = {
      inherit user profile;
    };
  };

in
{
  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit pkdjz world horizon; };
    sharedModules = [ homeModule ];
    useGlobalPkgs = true;
    users = mapAttrs mkUserConfig horizon.users;
  };
}
