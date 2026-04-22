{
  lib,
  pkgs,
  user,
  inputs,
  ...
}:
let
  inherit (user.methods) sizedAtLeast;
  system = pkgs.stdenv.hostPlatform.system;
in
lib.mkIf sizedAtLeast.med {
  home.packages = [ inputs.mentci-tools.packages.${system}.cli ];
}
