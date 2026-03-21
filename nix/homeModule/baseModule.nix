{
  pkgs,
  user,
  ...
}:
{
  config = {
    home = {
      username = user.name;
      homeDirectory = "/home/" + user.name;
      # TODO
      stateVersion = "25.05";
    };

    stylix = {
      enable = true;
      autoEnable = true;
      polarity = "dark";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
      targets = {
        sway.enable = false;
        hyprland.enable = false;
        neovim.enable = false;
        emacs.enable = false;
        vim.enable = false;
        waybar.enable = false;
        swaylock.enable = false;
      };
      image = pkgs.runCommand "wallpaper.png" {
        nativeBuildInputs = [ pkgs.imagemagick ];
      } ''
        magick -size 1920x1080 xc:#1d2021 $out
      '';
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
