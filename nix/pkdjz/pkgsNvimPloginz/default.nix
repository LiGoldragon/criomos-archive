{
  self,
  kor,
  lib,
  pkgs,
  bildNvimPlogin,
}:
let
  inherit (kor) mkLambda;

  ovyridynPkgs = pkgs // {
    buildVimPluginFrom2Nix = bildNvimPlogin;
  };

  overridesLambda = import (self + /pkgs/misc/vim-plugins/overrides.nix);

  overrides = mkLambda {
    lambda = overridesLambda;
    closure = ovyridynPkgs;
  };

  lambda = import (self + /pkgs/misc/vim-plugins/generated.nix);

  closure = ovyridynPkgs // {
    inherit overrides;
  };

  plugins = mkLambda {
    inherit lambda closure;
  };

  brokenPlugins = [ "minimap-vim" ];

in
removeAttrs plugins brokenPlugins
