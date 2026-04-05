{
  lib,
  horizon,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
in
lib.mkIf behavesAs.edge {
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = false;
    settings = {
      bar.widgetSettings.Battery.displayMode = "graphic-full";
    };
  };
}
