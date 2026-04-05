{
  pkgs,
  lib,
  horizon,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
  terminal = "${pkgs.ghostty}/bin/ghostty";
  launcher = "${pkgs.nwg-drawer}/bin/nwg-drawer";
  powerMenu = "${pkgs.nwg-bar}/bin/nwg-bar";
  swayncClient = "${pkgs.swaynotificationcenter}/bin/swaync-client";

  sfwbarConfig = pkgs.writeText "sfwbar.config" ''
    Set Term = "${terminal}"
    Set VolumeAction = "pwvucontrol"

    TriggerAction "SIGRTMIN+1", SwitcherEvent "forward"
    TriggerAction "SIGRTMIN+2", SwitcherEvent "back"

    placer {
      xorigin = 5
      yorigin = 5
      xstep = 5
      ystep = 5
      children = true
    }

    switcher {
      interval = 700
      icons = true
      labels = false
      cols = 5
    }

    include("winops.widget")

    layout {
      size = "100%"
      layer = "top"
      mirror = "*"
      exclusive_zone = "auto"
      css = "* { min-height: 28px; }"

      # App launcher
      button {
        value = "view-app-grid-symbolic"
        action = Exec "${launcher}"
        css = "* { min-height: 24px; min-width: 24px; padding: 0 8px; }"
      }

      # Running windows
      taskbar {
        style = "taskbar"
        rows = 1
        icons = true
        labels = true
        sort = false
        action[3] = Menu "winops"
        action[Drag] = Focus
      }

      # Spacer
      label {
        css = "* { -GtkWidget-hexpand: true; }"
      }

      include("volume.widget")
      include("network-module.widget")
      include("battery-svg.widget")

      tray {
        rows = 1
      }

      # Clock
      grid {
        css = "* { -GtkWidget-direction: bottom; }"
        label {
          value = Time("%H:%M")
          style = "clock"
        }
        label {
          value = Time("%a %d")
          style = "clock"
        }
      }

      # Notifications
      button {
        value = "preferences-system-notifications-symbolic"
        action = Exec "${swayncClient} -t -sw"
        css = "* { min-height: 16px; min-width: 16px; padding: 0 4px; }"
      }

      # Power
      button {
        value = "system-shutdown-symbolic"
        action = Exec "${powerMenu}"
        css = "* { min-height: 16px; min-width: 16px; padding: 0 6px; }"
      }
    }

    #CSS

    button,
    button image {
      min-height: 0px;
      outline-style: none;
      box-shadow: none;
      background-image: none;
      border-image: none;
    }

    label {
      font: 13px "IosevkaTerm Nerd Font";
      -GtkWidget-vexpand: true;
      -GtkWidget-valign: center;
    }

    image {
      -ScaleImage-symbolic: true;
    }

    button#module {
      border: none;
      padding: 2px;
      margin: 0px;
      -GtkWidget-vexpand: true;
    }

    button#module image {
      min-height: 16px;
      min-width: 16px;
      padding: 0px;
      margin: 0px;
      -GtkWidget-valign: center;
      -GtkWidget-vexpand: true;
    }

    button#taskbar_item {
      padding: 2px 6px;
      border-radius: 4px;
      border-width: 0px;
      -GtkWidget-hexpand: false;
    }

    button#taskbar_item.focused {
      background-color: alpha(@theme_selected_bg_color, 0.4);
    }

    button#taskbar_item.minimized label {
      color: alpha(currentColor, 0.5);
    }

    button#taskbar_item:hover {
      background-color: alpha(@theme_fg_color, 0.1);
    }

    button#taskbar_item image {
      min-width: 20px;
      min-height: 20px;
      padding-right: 4px;
      -ScaleImage-symbolic: false;
    }

    button#tray_item {
      margin: 0px;
      border: none;
      padding: 0px;
    }

    button#tray_item.passive {
      -GtkWidget-visible: false;
    }

    button#tray_item image {
      -GtkWidget-valign: center;
      -GtkWidget-vexpand: true;
      min-height: 16px;
      min-width: 16px;
      padding: 2px;
      margin: 0px;
      border: none;
    }

    label#clock {
      padding: 0 4px;
      -GtkWidget-vexpand: true;
      -GtkWidget-valign: center;
      font: 10px "IosevkaTerm Nerd Font";
    }

    grid#switcher_item.focused image,
    grid#switcher_item.focused {
      background-color: alpha(@theme_selected_bg_color, 0.4);
    }

    grid#switcher_item image,
    grid#switcher_item {
      min-width: 50px;
      min-height: 50px;
      border-radius: 5px;
      padding: 5px;
      -GtkWidget-direction: right;
      -GtkWidget-hexpand: true;
      -ScaleImage-symbolic: false;
    }

    window#switcher {
      border: 1px solid @borders;
      border-radius: 6px;
      padding: 40px;
      -GtkWidget-hexpand: true;
    }

    grid#switcher {
      border-radius: 5px;
      padding: 5px;
      -GtkWidget-hexpand: true;
    }
  '';
in
lib.mkIf behavesAs.edge {
  home.packages = [
    pkgs.sfwbar
    pkgs.nwg-drawer
    pkgs.nwg-bar
    pkgs.nwg-look
    pkgs.nwg-displays
    pkgs.nwg-clipman
    pkgs.swaynotificationcenter
  ];

  xdg.configFile."sfwbar/sfwbar.config".source = sfwbarConfig;

  services.swaync.enable = true;
}
