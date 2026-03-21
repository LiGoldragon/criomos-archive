{
  pkgs,
  lib,
  user,
  ...
}:
let
  darkScheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  lightScheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-light-hard.yaml";

  parseScheme = scheme:
    (lib.importJSON (pkgs.runCommand "base16-to-json" {
      nativeBuildInputs = [ pkgs.yq-go ];
    } ''
      yq -o=json '.' ${scheme} > $out
    '')).palette;

  dark = parseScheme darkScheme;
  light = parseScheme lightScheme;

  /*
    Generate waybar CSS with base16 @define-color variables.
    This is written as a real file by darkman, not managed by HM.
  */
  mkWaybarCss = c: pkgs.writeText "waybar-style.css" ''
    @define-color base00 ${c.base00}; @define-color base01 ${c.base01};
    @define-color base02 ${c.base02}; @define-color base03 ${c.base03};
    @define-color base04 ${c.base04}; @define-color base05 ${c.base05};
    @define-color base06 ${c.base06}; @define-color base07 ${c.base07};

    @define-color base08 ${c.base08}; @define-color base09 ${c.base09};
    @define-color base0A ${c.base0A}; @define-color base0B ${c.base0B};
    @define-color base0C ${c.base0C}; @define-color base0D ${c.base0D};
    @define-color base0E ${c.base0E}; @define-color base0F ${c.base0F};

    window#waybar, tooltip {
        background: alpha(@base00, 0.95);
        color: @base05;
    }

    * {
        font-family: "FiraMono Nerd Font";
        font-size: 14px;
    }

    tooltip { border-color: @base0D; }
    tooltip label { color: @base05; }

    #wireplumber, #pulseaudio, #sndio,
    #upower, #battery,
    #network, #user, #clock, #backlight,
    #cpu, #disk, #idle_inhibitor, #temperature,
    #mpd, #language, #keyboard-state, #memory,
    #window, #bluetooth { padding: 0 5px; }

    .modules-left #workspaces button,
    .modules-center #workspaces button,
    .modules-right #workspaces button {
        border-bottom: 3px solid transparent;
    }
    .modules-left #workspaces button.focused,
    .modules-left #workspaces button.active,
    .modules-center #workspaces button.focused,
    .modules-center #workspaces button.active,
    .modules-right #workspaces button.focused,
    .modules-right #workspaces button.active {
        border-bottom: 3px solid @base05;
    }
  '';

  darkWaybarCss = mkWaybarCss dark;
  lightWaybarCss = mkWaybarCss light;

  /*
    OSC escape sequences for terminal color switching.
    base16 → ANSI mapping (base16-shell order).
  */
  mkOscSequence = c:
    let osc = n: color: ''\033]4;${toString n};${color}\007'';
    in ''
      ${osc 0 c.base00}${osc 1 c.base08}${osc 2 c.base0B}${osc 3 c.base0A}\
      ${osc 4 c.base0D}${osc 5 c.base0E}${osc 6 c.base0C}${osc 7 c.base05}\
      ${osc 8 c.base03}${osc 9 c.base08}${osc 10 c.base0B}${osc 11 c.base0A}\
      ${osc 12 c.base0D}${osc 13 c.base0E}${osc 14 c.base0C}${osc 15 c.base07}\
      \033]10;${c.base05}\007\033]11;${c.base00}\007\033]12;${c.base05}\007'';

  strip = color: builtins.substring 1 6 color;

  /*
    mkApplyScript: darkman calls this on sunrise/sunset.
    Writes real config files and reloads all running apps.
  */
  mkApplyScript = { mode, scheme, waybarCss }:
    let
      c = parseScheme scheme;
      oscSeq = mkOscSequence c;
      dconfMode = if mode == "dark" then "prefer-dark" else "prefer-light";
      emacsTheme = if mode == "dark" then "modus-vivendi" else "modus-operandi";
    in
    pkgs.writeShellScript "apply-${mode}" ''
      # GTK via dconf (portal-aware apps: Firefox, Electron, ghostty)
      ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'${dconfMode}'"

      # Waybar: write real CSS file, restart
      mkdir -p "$HOME/.config/waybar"
      cp -f ${waybarCss} "$HOME/.config/waybar/style.css"
      chmod 644 "$HOME/.config/waybar/style.css"
      ${pkgs.procps}/bin/pkill -9 waybar 2>/dev/null || true
      sleep 0.3
      ${pkgs.procps}/bin/pgrep -x waybar >/dev/null || { waybar & disown; }

      # Terminals: OSC escape sequences to all PTYs
      SEQ="${oscSeq}"
      for pty in /dev/pts/[0-9]*; do
        printf "$SEQ" > "$pty" 2>/dev/null || true
      done

      # Hyprland borders
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border "rgb(${strip c.base0E}) rgb(${strip c.base0D}) 45deg" 2>/dev/null || true
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border "rgb(${strip c.base01})" 2>/dev/null || true

      # Emacs
      ${pkgs.emacs-pgtk}/bin/emacsclient --eval "(load-theme '${emacsTheme} t)" 2>/dev/null || true

      # Persist mode for new terminals
      mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman"
      echo "${mode}" > "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode"
    '';

  applyDark = mkApplyScript { mode = "dark"; scheme = darkScheme; waybarCss = darkWaybarCss; };
  applyLight = mkApplyScript { mode = "light"; scheme = lightScheme; waybarCss = lightWaybarCss; };

  /*
    Shell hook: new terminals get correct colors via OSC on startup.
  */
  lightOsc = mkOscSequence light;
  terminalInitHook = ''
    __darkman_init_theme() {
      local mode
      mode=$(cat "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode" 2>/dev/null) || return
      if [ "$mode" = "light" ]; then
        printf "${lightOsc}"
      fi
    }
    __darkman_init_theme
  '';

in
{
  config = {
    home = {
      username = user.name;
      homeDirectory = "/home/" + user.name;
      # TODO
      stateVersion = "25.05";
      packages = [
        (pkgs.writeShellScriptBin "theme-dark" ''${pkgs.darkman}/bin/darkman set dark'')
        (pkgs.writeShellScriptBin "theme-light" ''${pkgs.darkman}/bin/darkman set light'')
      ];
    };

    programs.zsh.initContent = lib.mkBefore terminalInitHook;

    services.darkman = {
      enable = true;
      settings = {
        lat = 36.7;
        lng = -4.4;
        dbusserver = true;
        portal = true;
      };
      darkModeScripts.switch = ''${applyDark}'';
      lightModeScripts.switch = ''${applyLight}'';
    };

    stylix = {
      enable = true;
      autoEnable = true;
      polarity = "dark";
      base16Scheme = darkScheme;
      targets = {
        ghostty.enable = false;
        waybar.enable = false;
      };
      image = pkgs.runCommand "wallpaper.png" {
        nativeBuildInputs = [ pkgs.imagemagick ];
      } ''
        magick -size 1920x1080 xc:${dark.base00} $out
      '';
      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.fira-mono;
          name = "FiraMono Nerd Font";
        };
        sansSerif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };
        sizes.terminal = 14;
      };
    };
  };
}
