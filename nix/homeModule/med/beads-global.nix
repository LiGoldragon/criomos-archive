{
  lib,
  pkgs,
  config,
  user,
  inputs,
  ...
}:
let
  inherit (user.methods) isCodeDev sizedAtLeast;
  system = pkgs.stdenv.hostPlatform.system;

  beadsPkg = inputs.mentci-tools.packages.${system}.beads;
  doltPkg = pkgs.dolt;

  port = 13306;
  dataDir = "${config.home.homeDirectory}/.beads/shared-server";
in
lib.mkIf (isCodeDev && sizedAtLeast.med) {
  home.packages = [ beadsPkg ];

  systemd.user.services.beads-global = {
    Unit = {
      Description = "beads shared dolt sql-server (backs bd --global / shared-server mode)";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${dataDir}";
      ExecStart = "${doltPkg}/bin/dolt sql-server --host 127.0.0.1 --port ${toString port} --data-dir ${dataDir}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
