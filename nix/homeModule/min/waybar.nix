{
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

  # TODO - module for packages
  sysMonitor = "btm";
  launcher = "rofi -show drun";
  displaySystemInfo = "hyprctl dispatch exec '[float; center; size 950 650] foot --override font_size=14 --title float_foot ${sysMonitor}'";
  launchVolumeControl = "pwvucontrol";

in
{
  programs.waybar = {
    enable = behavesAs.edge;

    settings.main = {
      position = "bottom";
      layer = "top";
      height = 28;
      margin-top = 0;
      margin-bottom = 0;
      margin-left = 0;
      margin-right = 0;
      modules-left = [
        "custom/launcher"
        "hyprland/workspaces"
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
        "hyprland/language"
        "custom/notification"
      ];
      clock = {
        calendar = {
          format = {
            today = "<span color='${green}'><b>{}</b></span>";
          };
        };
        format = "  {:%H:%M}";
        tooltip = "true";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = "  {:%d/%m}";
      };
      "hyprland/workspaces" = {
        active-only = false;
        disable-scroll = true;
        format = "{icon}";
        on-click = "activate";
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
          sort-by-number = true;
        };
        persistent-workspaces = {
          "1" = [ ];
          "2" = [ ];
          "3" = [ ];
          "4" = [ ];
          "5" = [ ];
        };
      };
      cpu = {
        format = "<span foreground='${green}'> </span> {usage}%";
        format-alt = "<span foreground='${green}'> </span> {avg_frequency} GHz";
        interval = 2;
        on-click-right = displaySystemInfo;
      };
      memory = {
        format = "<span foreground='${cyan}'>󰟜 </span>{}%";
        format-alt = "<span foreground='${cyan}'>󰟜 </span>{used} GiB"; # 
        interval = 2;
        on-click-right = displaySystemInfo;
      };
      disk = {
        # path = "/";
        format = "<span foreground='${orange}'>󰋊 </span>{percentage_used}%";
        interval = 60;
        on-click-right = displaySystemInfo;
      };
      network = {
        format-wifi = "<span foreground='${magenta}'> </span> {signalStrength}%";
        format-ethernet = "<span foreground='${magenta}'>󰀂 </span>";
        tooltip-format = "Connected to {essid} {ifname} via {gwaddr}";
        format-linked = "{ifname} (No IP)";
        format-disconnected = "<span foreground='${magenta}'>󰖪 </span>";
      };
      tray = {
        icon-size = 20;
        spacing = 8;
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "<span foreground='${blue}'> </span> {volume}%";
        format-icons = {
          default = [ "<span foreground='${blue}'> </span>" ];
        };
        scroll-step = 2;
        on-click = launchVolumeControl;
      };
      battery = {
        format = "<span foreground='${yellow}'>{icon}</span> {capacity}%";
        format-icons = [
          " "
          " "
          " "
          " "
          " "
        ];
        format-charging = "<span foreground='${yellow}'> </span>{capacity}%";
        format-full = "<span foreground='${yellow}'> </span>{capacity}%";
        format-warning = "<span foreground='${yellow}'> </span>{capacity}%";
        interval = 5;
        states = {
          warning = 20;
        };
        format-time = "{H}h{M}m";
        tooltip = true;
        tooltip-format = "{time}";
      };
      "hyprland/language" = {
        format = "<span foreground='${yellow}'> </span> {}";
        format-fr = "FR";
        format-en = "US";
      };
      "custom/launcher" = {
        format = "";
        on-click = launcher;
        tooltip = "true";
      };
      "custom/notification" = {
        tooltip = false;
        format = "{icon} ";
        format-icons = {
          notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          none = "  <span foreground='${red}'></span>";
          dnd-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          dnd-none = "  <span foreground='${red}'></span>";
          inhibited-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          inhibited-none = "  <span foreground='${red}'></span>";
          dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          dnd-inhibited-none = "  <span foreground='${red}'></span>";
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
