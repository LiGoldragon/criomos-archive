{
  hob,
  bildNvimPlogin,
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

  bildNvimLuaPlogin =
    {
      name,
      self,
      ovyraidz,
    }:
    let
    in
    bildNvimPlogin (
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
    bildNvimLuaPlogin { inherit name self ovyraidz; };

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
