{
  pkgs,
  horizon,
  config,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
  colors = config.lib.stylix.colors.withHashtag;

  red = colors.base08;
  green = colors.base0B;
  yellow = colors.base0A;
  blue = colors.base0D;
  muted = colors.base04;
  fg = colors.base05;

  sysMonitor = "btm";
  displaySystemInfo = "${pkgs.ghostty}/bin/ghostty -e ${sysMonitor}";
  launchVolumeControl = "pwvucontrol";

in
{
  programs.waybar = {
    enable = behavesAs.edge;

    settings.main = {
      position = "bottom";
      layer = "top";
      height = 30;
      margin-top = 0;
      margin-bottom = 4;
      margin-left = 8;
      margin-right = 8;
      modules-left = [
        "niri/workspaces"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "cpu"
        "memory"
        "disk"
        "pulseaudio"
        "network"
        "battery"
        "niri/language"
        "tray"
        "custom/power"
      ];
      clock = {
        calendar = {
          format = {
            today = "<span color='${green}'><b>{}</b></span>";
          };
        };
        format = " {:%H:%M}";
        tooltip = "true";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = " {:%d/%m}";
      };
      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
          "1" = "I";
          "2" = "II";
          "3" = "III";
          "4" = "IV";
          "5" = "V";
          "6" = "VI";
          "7" = "VII";
          "8" = "VIII";
          "9" = "IX";
          "10" = "X";
        };
      };
      cpu = {
        format = " {usage}%";
        format-alt = " {avg_frequency} GHz";
        interval = 2;
        on-click-right = displaySystemInfo;
      };
      memory = {
        format = "󰟜 {}%";
        format-alt = "󰟜 {used} GiB";
        interval = 2;
        on-click-right = displaySystemInfo;
      };
      disk = {
        format = "󰋊 {percentage_used}%";
        interval = 60;
        on-click-right = displaySystemInfo;
      };
      network = {
        format-wifi = "  {signalStrength}%";
        format-ethernet = "󰀂 ";
        tooltip-format = "Connected to {essid} {ifname} via {gwaddr}";
        format-linked = "{ifname} (No IP)";
        format-disconnected = "󰖪 ";
      };
      tray = {
        icon-size = 20;
        spacing = 8;
      };
      pulseaudio = {
        format = "{icon}{volume}%";
        format-muted = " {volume}%";
        format-icons = {
          default = [ " " ];
        };
        scroll-step = 2;
        on-click = launchVolumeControl;
      };
      battery = {
        format = "{icon}{capacity}%";
        format-icons = [
          " "
          " "
          " "
          " "
          " "
        ];
        format-charging = " {capacity}%";
        format-full = " {capacity}%";
        format-warning = " {capacity}%";
        interval = 5;
        states = {
          warning = 20;
        };
        format-time = "{H}h{M}m";
        tooltip = true;
        tooltip-format = "{time}";
      };
      "niri/language" = {
        format = " {}";
        format-fr = "FR";
        format-en = "US";
      };
      "custom/power" = {
        format = "⏻";
        tooltip = false;
        on-click = "${pkgs.wofi}/bin/wofi --show dmenu --prompt 'Session' --cache-file /dev/null <<< $'Lock\nSuspend\nLogout\nReboot\nShutdown' | ${pkgs.bash}/bin/bash -c 'read choice; case $choice in Lock) loginctl lock-session;; Suspend) systemctl suspend;; Logout) niri msg action quit;; Reboot) systemctl reboot;; Shutdown) systemctl poweroff;; esac'";
      };
    };
  };
}
