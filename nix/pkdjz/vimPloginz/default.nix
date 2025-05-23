{
  hob,
  vimUtils,
  fzf,
}:
let
  inherit (builtins) mapAttrs;
  inherit (vimUtils) buildVimPluginFrom2Nix;

  implaidSpoks = (import ./../nvimPloginz/spoksFromHob.nix) hob;

  eksplisitSpoks = { };

  mkImplaidSpoks = name: spok: spok;

  spoks = eksplisitSpoks // (mapAttrs (n: s: s) implaidSpoks);

  fzf-vim-core = buildVimPluginFrom2Nix {
    pname = "fzf";
    version = fzf.version;
    src = fzf.src;
  };

  ovyraidzIndeks = {
    fzf-vim = {
      dependencies = [ fzf-vim-core ];
    };
  };

  forkIndeks = { };

  bildVimPlogin =
    {
      name,
      self,
      ovyraidz,
    }:
    let
    in
    buildVimPluginFrom2Nix (
      {
        pname = name;
        version = self.shortRev;
        src = self;
      }
      // ovyraidz
    );

  mkSpok =
    name: self:
    let
      ovyraidz = ovyraidzIndeks.${name} or { };
    in
    bildVimPlogin { inherit name self ovyraidz; };

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
