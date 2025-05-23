{
  pkgs,
  lib,
  horizon,
  kor,
  criomOS,
  world,
  homeModule,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib) mkOverride;
  inherit (world) mkHomeConfig pkdjz;

  useMetylModule = horizon.astra.machine.species == "metyl";
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
  boot = {
    supportedFilesystems = mkOverride 10 [
      "btrfs"
      "vfat"
      "xfs"
      "ntfs"
    ];
  };

  hardware.enableAllFirmware = useMetylModule;

  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit
        kor
        pkdjz
        world
        horizon
        ;
    };
    sharedModules = [ homeModule ];
    useGlobalPkgs = true;
    users = mapAttrs mkUserConfig horizon.users;
  };

  isoImage = {
    isoBaseName = "criomOS";
    volumeID = "criomOS-${criomOS.shortRev}-${pkgs.stdenv.hostPlatform.uname.processor}";

    makeUsbBootable = true;
    makeEfiBootable = true;
  };

}
