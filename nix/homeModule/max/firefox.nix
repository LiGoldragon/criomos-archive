{ pkgs, ... }:
let

in
{
  programs = {
    browserpass = {
      enable = true;
      browsers = [ "firefox" ];
    };
  };

  home = {
    packages = with pkgs; [
      firefox-bin
    ];
  };
}
