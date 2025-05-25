{
  hob,
  buildNvimPlogin,
  fzf,
}:
let
  inherit (builtins) mapAttrs;

  implaidSpoks = {
    inherit (hob)
      nvim-lspconfig
      ;
  };

  eksplisitSpoks = {
    plenary-kor = hob.plenary-nvim;
  };

  spoks = eksplisitSpoks // (mapAttrs (n: s: s) implaidSpoks);

  ovyraidzIndeks = {
    plenary-kor = {
      installPhase = ''
        runHook preInstall
        mkdir -p $out/lua
        cp -r lua/plenary $out/lua/
        runHook postInstall
      '';
    };
  };

  buildNvimLuaPlogin =
    {
      name,
      self,
      ovyraidz,
    }:
    let
    in
    buildNvimPlogin (
      {
        pname = name;
        version = self.shortRev;
        src = self;
        namePrefix = "nvimLuaPlogin";
        components = [
          "lua"
          "queries"
          "doc"
        ];
      }
      // ovyraidz
    );

  mkSpok =
    name: self:
    let
      ovyraidz = ovyraidzIndeks.${name} or { };
    in
    buildNvimLuaPlogin { inherit name self ovyraidz; };

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
