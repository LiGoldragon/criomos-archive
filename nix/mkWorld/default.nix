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
  inherit (kor) mkLamdy optionalAttrs genAttrs;
  inherit (world) pkdjz mkZolaWebsite;

  mkTypedZolaWebsite =
    name: flake:
    mkZolaWebsite {
      src = flake;
      name = flake.name or name;
    };

  meikSobWorld =
    SobWorld@{
      lamdy,
      modz,
      self ? src,
      src ? self,
      sobWorlds ? { },
    }:
    let
      Modz = [
        "pkgs"
        "pkgsStatic"
        "pkgsSet"
        "hob"
        "mkPkgs"
        "pkdjz"
        "world"
        "worldSet"
      ];

      useMod = genAttrs Modz (n: (l.elem n modz));

      # Warning: sets shadowing
      klozyr =
        optionalAttrs useMod.pkgs pkgs
        // optionalAttrs useMod.pkgsStatic pkgs.pkgsStatic
        // optionalAttrs useMod.world world
        // optionalAttrs useMod.pkdjz pkdjz
        // optionalAttrs useMod.hob { inherit hob; }
        // optionalAttrs useMod.pkgsSet { inherit pkgs; }
        // optionalAttrs useMod.worldSet { inherit world; }
        // optionalAttrs useMod.mkPkgs { inherit mkPkgs; }
        // sobWorlds
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
    mkLamdy { inherit klozyr lamdy; };

  mkWorldFunction =
    flake:
    meikSobWorld {
      modz = [
        "pkgs"
        "pkdjz"
      ];
      src = flake;
      lamdy = flake.function;
    };

  makeSpoke =
    spokName:
    fleik@{ ... }:
    let
      priMeikSobWorld =
        name:
        SobWorld@{
          modz ? [ ],
          lamdy,
          ...
        }:
        let
          src = SobWorld.src or (SobWorld.self or fleik);
          self = src;
        in
        meikSobWorld {
          inherit
            src
            self
            modz
            lamdy
            ;
        };

      priMeikHobWorld =
        name:
        HobWorld@{
          modz ? [ "pkgs" ],
          lamdy,
          ...
        }:
        let
          implaidSelf = hob.${name} or null;
          src = HobWorld.src or (HobWorld.self or implaidSelf);
          self = src;
        in
        meikSobWorld {
          inherit
            src
            self
            modz
            lamdy
            ;
        };

      meikHobWorlds =
        HobWorlds:
        let
          priHobWorlds = HobWorlds hob;
        in
        mapAttrs priMeikHobWorld priHobWorlds;

      meikSobWorlds =
        SobWorlds:
        let
          priMeikSobWorlds =
            name:
            SobWorld@{
              modz ? [ ],
              lamdy,
              ...
            }:
            let
              src = SobWorld.src or (SobWorld.self or fleik);
              self = src;
            in
            meikSobWorld {
              inherit
                src
                self
                modz
                lamdy
                sobWorlds
                ;
            };

          sobWorlds = mapAttrs priMeikSobWorlds SobWorlds;
        in
        sobWorlds;

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
      meikHobWorlds fleik.HobWorlds
    else if (hasAttr "HobWorld" fleik) then
      priMeikHobWorld spokName (fleik.HobWorld hob)
    else if (hasAttr "SobWorlds" fleik) then
      meikSobWorlds fleik.SobWorlds
    else if (hasAttr "SobWorld" fleik) then
      priMeikSobWorld spokName fleik.SobWorld
    else if (isWebpageSpok spokName) then
      mkZolaWebsite { src = fleik; }
    # else if hasFleikFile then makeFleik
    else
      fleik // optionalSystemAttributes;

  world = mapAttrs makeSpoke hob;

in
world
