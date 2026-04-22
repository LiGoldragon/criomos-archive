{
  lib,
  pkgs,
  user,
  inputs,
  ...
}:
let
  inherit (user.methods) isCodeDev sizedAtLeast;
  system = pkgs.stdenv.hostPlatform.system;
in
lib.mkIf (isCodeDev && sizedAtLeast.med) {
  home.packages = [ inputs.mentci-tools.packages.${system}.beads ];
}
