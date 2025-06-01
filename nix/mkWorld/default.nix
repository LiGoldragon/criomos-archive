{
  lib,
  pkgs,
  hob,
  system,
  localSources,
}:
let
  l = lib // builtins;
  inherit (builtins) hasAttr mapAttrs readDir;
  inherit (localSources) kor nodeNames mkPkgs;
  inherit (kor) mkLambda optionalAttrs genAttrs;
  inherit (world) pkdjz mkZolaWebsite;

  mkSubWorld =
    SubWorld@{
      lambda,
      mods,
      self ? src,
      src ? self,
      subWorlds ? { },
    }:
    let
      Mods = [
        "pkgs"
        "pkgsStatic"
        "pkgsSet"
        "hob"
        "mkPkgs"
        "pkdjz"
        "world"
        "worldSet"
      ];

      useMod = genAttrs Mods (n: (l.elem n mods));

      # Warning: sets shadowing
      closure =
        optionalAttrs useMod.pkgs pkgs
        // optionalAttrs useMod.pkgsStatic pkgs.pkgsStatic
        // optionalAttrs useMod.world world
        // optionalAttrs useMod.pkdjz pkdjz
        // optionalAttrs useMod.hob { inherit hob; }
        // optionalAttrs useMod.pkgsSet { inherit pkgs; }
        // optionalAttrs useMod.worldSet { inherit world; }
        // optionalAttrs useMod.mkPkgs { inherit mkPkgs; }
        // subWorlds
        // {
          inherit kor lib;
        }
        // {
          inherit system;
        }
        # TODO: deprecate `self` for `src`
        // {
          inherit self;
        }
        // {
          src = self;
        };

    in
    mkLambda { inherit closure lambda; };

  makeSpoke =
    spokName:
    spoke@{ ... }:
    let
      priMkSubWorld =
        name:
        SubWorld@{
          mods ? [ ],
          lambda,
          ...
        }:
        let
          src = SubWorld.src or (SubWorld.self or spoke);
          self = src;
        in
        mkSubWorld {
          inherit
            src
            self
            mods
            lambda
            ;
        };

      priMkHobWorld =
        name:
        HobWorld@{
          mods ? [ "pkgs" ],
          lambda,
          ...
        }:
        let
          implaidSelf = hob.${name} or null;
          src = HobWorld.src or (HobWorld.self or implaidSelf);
          self = src;
        in
        mkSubWorld {
          inherit
            src
            self
            mods
            lambda
            ;
        };

      mkHobWorlds =
        HobWorlds:
        let
          priHobWorlds = HobWorlds hob;
        in
        mapAttrs priMkHobWorld priHobWorlds;

      mkSubWorlds =
        SubWorlds:
        let
          priMkSubWorlds =
            name:
            SubWorld@{
              mods ? [ ],
              lambda,
              ...
            }:
            let
              src = SubWorld.src or (SubWorld.self or spoke);
              self = src;
            in
            mkSubWorld {
              inherit
                src
                self
                mods
                lambda
                subWorlds
                ;
            };

          subWorlds = mapAttrs priMkSubWorlds SubWorlds;
        in
        subWorlds;

      # TODO - Bad design
      spokeIsWebsite = spokeName: spokName == (spokeName + "Website");

      optionalSystemAttributes = {
        packages = spoke.packages.${system} or { };
        legacyPackages = spoke.legacyPackages.${system} or { };
      };

    in
    if (hasAttr "HobWorlds" spoke) then
      mkHobWorlds spoke.HobWorlds
    else if (hasAttr "SubWorlds" spoke) then
      mkSubWorlds spoke.SubWorlds
    else if (hasAttr "SubWorld" spoke) then
      priMkSubWorld spokName spoke.SubWorld
    else if (spokeIsWebsite spokName) then
      mkZolaWebsite { src = spoke; }
    else
      spoke // optionalSystemAttributes;

  world = mapAttrs makeSpoke hob;

in
world
