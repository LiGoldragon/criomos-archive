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

  mkTypedZolaWebsite =
    name: flake:
    mkZolaWebsite {
      src = flake;
      name = flake.name or name;
    };

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

  mkWorldFunction =
    flake:
    mkSubWorld {
      mods = [
        "pkgs"
        "pkdjz"
      ];
      src = flake;
      lambda = flake.function;
    };

  makeSpoke =
    spokName:
    fleik@{ ... }:
    let
      priMkSubWorld =
        name:
        SubWorld@{
          mods ? [ ],
          lambda,
          ...
        }:
        let
          src = SubWorld.src or (SubWorld.self or fleik);
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
              src = SubWorld.src or (SubWorld.self or fleik);
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

      mkNodeWebpageName = nodeName: [
        (nodeName + "Webpage")
        (nodeName + "Website")
      ];

      nodeWebpageSpokNames = lib.concatMap mkNodeWebpageName nodeNames;

      isWebpageSpok = spokName: l.elem spokName nodeWebpageSpokNames;

      optionalSystemAttributes = {
        packages = fleik.packages.${system} or { };
        legacyPackages = fleik.legacyPackages.${system} or { };
      };

      hasFleikFile =
        let
          fleikDirectoryFiles = readDir fleik;
        in
        hasAttr "fleik.nix" fleikDirectoryFiles;

      makeFleik = { };

      mkNixpkgsHob =
        nixpkgsSet:
        let
          mkPkgsFromNameValue =
            name: value:
            mkPkgs {
              inherit system;
              nixpkgs = value;
            };
        in
        mapAttrs mkPkgsFromNameValue nixpkgsSet;

      typedFlakeMakerIndex = {
        nixpkgsHob = mkNixpkgsHob fleik.value;
        worldFunction = mkWorldFunction fleik;
        zolaWebsite = mkTypedZolaWebsite spokName fleik;
      };

      mkTypedFlake =
        let
          inherit (fleik) type;
        in
        builtins.getAttr type typedFlakeMakerIndex;

    in
    if (hasAttr "type" fleik) then
      mkTypedFlake
    else if (hasAttr "HobWorlds" fleik) then
      mkHobWorlds fleik.HobWorlds
    else if (hasAttr "HobWorld" fleik) then
      priMkHobWorld spokName (fleik.HobWorld hob)
    else if (hasAttr "SubWorlds" fleik) then
      mkSubWorlds fleik.SubWorlds
    else if (hasAttr "SubWorld" fleik) then
      priMkSubWorld spokName fleik.SubWorld
    else if (isWebpageSpok spokName) then
      mkZolaWebsite { src = fleik; }
    # else if hasFleikFile then makeFleik
    else
      fleik // optionalSystemAttributes;

  world = mapAttrs makeSpoke hob;

in
world
