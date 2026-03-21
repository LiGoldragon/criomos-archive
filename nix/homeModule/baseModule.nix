{
  pkgs,
  lib,
  config,
  user,
  ...
}:
let
  hmProfilePath = "$HOME/.local/state/nix/profiles/home-manager";

  darkWallpaper = pkgs.runCommand "wallpaper-dark.png" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    magick -size 1920x1080 xc:#1d2021 $out
  '';

  lightWallpaper = pkgs.runCommand "wallpaper-light.png" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    magick -size 1920x1080 xc:#fbf1c7 $out
  '';

  /*
    Generate OSC escape sequences to live-update terminal colors.
    base16 → ANSI 16-color mapping (standard base16-shell order):
      0=base00  1=base08  2=base0B  3=base0A  4=base0D  5=base0E  6=base0C  7=base05
      8=base03  9=base08 10=base0B 11=base0A 12=base0D 13=base0E 14=base0C 15=base07
    OSC 4;N;#rrggbb sets palette color N.
    OSC 10;#rrggbb sets foreground, OSC 11;#rrggbb sets background.
  */
  mkTerminalColorScript = scheme:
    let
      c = (lib.importJSON (pkgs.runCommand "base16-to-json" {
        nativeBuildInputs = [ pkgs.yq-go ];
      } ''
        yq -o=json '.' ${scheme} > $out
      '')).palette;
      osc = n: color: ''\033]4;${toString n};${color}\007'';
    in
    pkgs.writeShellScript "set-terminal-colors" ''
      SEQ=""
      # Palette (ANSI 0-15)
      SEQ+="${osc 0 c.base00}${osc 1 c.base08}${osc 2 c.base0B}${osc 3 c.base0A}"
      SEQ+="${osc 4 c.base0D}${osc 5 c.base0E}${osc 6 c.base0C}${osc 7 c.base05}"
      SEQ+="${osc 8 c.base03}${osc 9 c.base08}${osc 10 c.base0B}${osc 11 c.base0A}"
      SEQ+="${osc 12 c.base0D}${osc 13 c.base0E}${osc 14 c.base0C}${osc 15 c.base07}"
      # Foreground / background
      SEQ+="\033]10;${c.base05}\007"
      SEQ+="\033]11;${c.base00}\007"
      # Cursor color
      SEQ+="\033]12;${c.base05}\007"

      for pty in /dev/pts/[0-9]*; do
        printf "$SEQ" > "$pty" 2>/dev/null || true
      done
    '';

  darkScheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  lightScheme = "${pkgs.base16-schemes}/share/themes/gruvbox-light-hard.yaml";

  setDarkTermColors = mkTerminalColorScript darkScheme;
  setLightTermColors = mkTerminalColorScript lightScheme;

  reloadLiveApps = pkgs.writeShellScript "reload-live-apps" ''
    # Reload hyprland config (picks up new border colors)
    ${pkgs.hyprland}/bin/hyprctl reload 2>/dev/null || true

    # Restart waybar (reads new CSS/config from updated symlinks)
    ${pkgs.procps}/bin/pkill -x waybar 2>/dev/null || true
    sleep 0.3
    waybar &
    disown

    # Reload emacs theme
    ${pkgs.emacs-pgtk}/bin/emacsclient --eval '(when (fboundp '"'"'stylix-apply-theme) (stylix-apply-theme))' 2>/dev/null || true
  '';

  switchDark = pkgs.writeShellScript "switch-dark" ''
    gen=$(readlink -f ${hmProfilePath})
    "$gen/activate"
    ${setDarkTermColors}
    ${reloadLiveApps}
  '';

  switchLight = pkgs.writeShellScript "switch-light" ''
    gen=$(readlink -f ${hmProfilePath})
    "$gen/specialisation/light/activate"
    ${setLightTermColors}
    ${reloadLiveApps}
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
        (pkgs.writeShellScriptBin "theme-dark" ''exec ${switchDark}'')
        (lib.lowPrio (pkgs.writeShellScriptBin "theme-light" ''exec ${switchLight}''))
      ];
    };

    services.darkman = {
      enable = true;
      settings = {
        lat = 36.7;
        lng = -4.4;
        dbusserver = true;
        portal = true;
      };
      darkModeScripts = {
        gtk-theme = ''
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
        '';
        activate = ''${switchDark}'';
      };
      lightModeScripts = {
        gtk-theme = ''
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        '';
        activate = ''${switchLight}'';
      };
    };

    stylix = {
      enable = true;
      autoEnable = true;
      polarity = lib.mkDefault "dark";
      base16Scheme = lib.mkDefault "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
      image = lib.mkDefault darkWallpaper;
      cursor = {
        package = pkgs.bibata-cursors;
        name = lib.mkDefault "Bibata-Modern-Classic";
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

    specialisation.light.configuration = {
      stylix = {
        polarity = "light";
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-light-hard.yaml";
        image = lightWallpaper;
        cursor.name = "Bibata-Modern-Classic";
      };

      home.packages = [
        (pkgs.writeShellScriptBin "theme-light" ''echo "Already in light mode"'')
        (lib.lowPrio (pkgs.writeShellScriptBin "theme-dark" ''exec ${switchDark}''))
      ];
    };
  };
}
