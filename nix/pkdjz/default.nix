hob:

let
  pkdjz = {
    beaker = {
      lambda = import ./beaker;
      self = null;
    };

    buildNvimPlogin = {
      lambda = import ./buildNvimPlogin;
      mods = [
        "pkgs"
        "pkdjz"
      ];
      self = null;
    };

    home-manager = {
      lambda = import ./home-manager;
      mods = [
        "lib"
        "pkgs"
        "hob"
      ];
    };

    evalNixos = {
      lambda = import ./evalNixos;
      mods = [
        "lib"
        "pkgsSet"
      ];
      self = hob.nixpkgs;
    };

    kreitOvyraidz = {
      lambda = import ./kreitOvyraidz;
      mods = [
        "pkgs"
        "lib"
      ];
      self = null;
    };

    kynvyrt = {
      lambda = import ./kynvyrt;
      mods = [
        "pkgs"
        "world"
      ];
      self = null;
    };

    lib = {
      lambda = import ./lib;
      mods = [ ];
      self = hob.nixpkgs;
    };

    librem5-flash-image = {
      lambda = import ./librem5/flashImage.nix;
    };

    mach-nix = {
      lambda = import ./mach-nix;
    };

    mkEmacs = {
      lambda = import ./mkEmacs;
      mods = [
        "pkgsSet"
        "hob"
        "pkdjz"
      ];
      self = hob.emacs-overlay;
    };

    mfgtools = {
      lambda = import ./mfgtools;
    };

    nvimLuaPloginz = {
      lambda = import ./nvimPloginz/lua.nix;
      mods = [
        "hob"
        "pkdjz"
      ];
      self = null;
    };

    nvimPloginz = {
      lambda = import ./nvimPloginz;
      mods = [
        "hob"
        "pkdjz"
      ];
      self = null;
    };

    nerd-fonts = {
      lambda = import ./nerd-fonts;
      self = null;
    };

    pkgsNvimPloginz = {
      lambda = import ./pkgsNvimPloginz;
      mods = [
        "pkgsSet"
        "lib"
        "pkdjz"
      ];
      self = hob.nixpkgs;
    };

    shen-bootstrap = {
      lambda = import ./shen/bootstrap.nix;
      self = hob.shen;
    };

    shen-ecl-bootstrap = {
      lambda = import ./shen/ecl.nix;
      self = null;
    };

    remux = {
      lambda = import ./remux;
      self = hob.videocut;
    };

    shenPrelude.lambda = import ./shen/prelude.nix;

    slynkPackages = {
      lambda = import ./slynkPackages;
      self = null;
    };

    nix = {
      lambda = import ./nix;
      mods = [
        "pkgs"
        "pkdjz"
      ];
    };

    obs-ndi = {
      mods = [
        "pkgsSet"
        "pkgs"
        "pkdjz"
      ];
      src = null;
      lambda = import ./obs-ndi;
    };

    videocut = {
      lambda = import ./videocut;
      mods = [
        "pkgs"
        "pkdjz"
      ];
    };

    vimPloginz = {
      lambda = import ./vimPloginz;
      mods = [
        "pkgs"
        "pkdjz"
        "hob"
      ];
      self = null;
    };
  };

  aliases = {
    shen = pkdjz.shen-ecl-bootstrap;
  };

  adHoc = (import ./adHoc.nix) hob;

in
adHoc // pkdjz // aliases
