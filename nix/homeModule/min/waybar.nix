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
  magenta = colors.base0E;
  cyan = colors.base0C;
  orange = colors.base09;
  muted = colors.base04;

  # TODO - module for packages
  sysMonitor = "btm";
  launcher = "rofi -show drun";
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
        "custom/launcher"
        "niri/workspaces"
        "tray"
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
        "custom/notification"
      ];
      clock = {
        calendar = {
          format = {
            today = "<span color='${green}'><b>{}</b></span>";
          };
        };
        format = "  {:%H:%M}";
        tooltip = "true";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = "  {:%d/%m}";
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
        format = "<span foreground='${muted}'> </span>{usage}%";
        format-alt = "<span foreground='${muted}'> </span>{avg_frequency} GHz";
        interval = 2;
        on-click-right = displaySystemInfo;
      };
      memory = {
        format = "<span foreground='${muted}'>󰟜 </span>{}%";
        format-alt = "<span foreground='${muted}'>󰟜 </span>{used} GiB";
        interval = 2;
        on-click-right = displaySystemInfo;
      };
      disk = {
        format = "<span foreground='${muted}'>󰋊 </span>{percentage_used}%";
        interval = 60;
        on-click-right = displaySystemInfo;
      };
      network = {
        format-wifi = "<span foreground='${muted}'> </span>{signalStrength}%";
        format-ethernet = "<span foreground='${muted}'>󰀂 </span>";
        tooltip-format = "Connected to {essid} {ifname} via {gwaddr}";
        format-linked = "{ifname} (No IP)";
        format-disconnected = "<span foreground='${muted}'>󰖪 </span>";
      };
      tray = {
        icon-size = 20;
        spacing = 8;
      };
      pulseaudio = {
        format = "<span foreground='${muted}'>{icon}</span>{volume}%";
        format-muted = "<span foreground='${muted}'> </span>{volume}%";
        format-icons = {
          default = [ " " ];
        };
        scroll-step = 2;
        on-click = launchVolumeControl;
      };
      battery = {
        format = "<span foreground='${muted}'>{icon}</span>{capacity}%";
        format-icons = [
          " "
          " "
          " "
          " "
          " "
        ];
        format-charging = "<span foreground='${muted}'> </span>{capacity}%";
        format-full = "<span foreground='${muted}'> </span>{capacity}%";
        format-warning = "<span foreground='${yellow}'> </span>{capacity}%";
        interval = 5;
        states = {
          warning = 20;
        };
        format-time = "{H}h{M}m";
        tooltip = true;
        tooltip-format = "{time}";
      };
      "niri/language" = {
        format = "<span foreground='${muted}'> </span>{}";
        format-fr = "FR";
        format-en = "US";
      };
      "custom/launcher" = {
        format = "";
        on-click = launcher;
        tooltip = "true";
      };
      "custom/notification" = {
        tooltip = false;
        format = "{icon} ";
        format-icons = {
          notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          none = "  <span foreground='${muted}'></span>";
          dnd-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          dnd-none = "  <span foreground='${muted}'></span>";
          inhibited-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          inhibited-none = "  <span foreground='${muted}'></span>";
          dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          dnd-inhibited-none = "  <span foreground='${muted}'></span>";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };

    };
  };
}
