{
  pkgs,
  lib,
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

  switchDark = pkgs.writeShellScript "switch-dark" ''
    gen=$(readlink -f ${hmProfilePath})
    exec "$gen/activate"
  '';

  switchLight = pkgs.writeShellScript "switch-light" ''
    gen=$(readlink -f ${hmProfilePath})
    exec "$gen/specialisation/light/activate"
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
        activate = ''exec ${switchDark}'';
      };
      lightModeScripts = {
        gtk-theme = ''
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        '';
        activate = ''exec ${switchLight}'';
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
