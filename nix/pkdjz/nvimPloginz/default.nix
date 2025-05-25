{ hob, buildNvimPlogin }:
let
  inherit (builtins) mapAttrs;

  implaidSpoks = (import ./spoksFromHob.nix) hob;

  eksplisitSpoks = { };

  mkImplaidSpoks = name: spok: spok;

  spoks = eksplisitSpoks // (mapAttrs (n: s: s) implaidSpoks);

  ovyraidzIndeks = { };

  mkSpok =
    name: self:
    let
      ovyraidz = ovyraidzIndeks.${name} or { };
    in
    buildNvimPlogin (
      {
        pname = name;
        version = self.shortRev;
        src = self;
      }
      // ovyraidz
    );

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
