# Note: Inputs are kept below outputs
{
  description = "CriomOS";

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      localSources =
        let
          importInput = name: value: import value;
          modulePaths = {
            kor = ./nix/kor;
            mkPkgs = ./nix/mkPkgs;
            mkWorld = ./nix/mkWorld;
            mkCrioSphere = ./nix/mkCrioSphere;
            mkCrioZones = ./nix/mkCrioZones;
            mkCriomOS = ./nix/mkCriomOS;
            pkdjz = ./nix/pkdjz;
            homeModule = ./nix/homeModule;
            nodeNames = ./nodeNames.nix;
            files = ./nix/files; # TODO: use?
          };
        in
        mapAttrs importInput modulePaths;

      hob =
        let
          hobInputs = removeAttrs inputs nodeNames;
          adHocHobSpokes = {
            inherit (localSources) mkWebpage;
            pkdjz.HobWorlds = localSources.pkdjz;
          };
        in
        hobInputs // adHocHobSpokes;

      inherit (hob) flake-utils lib;
      inherit (localSources)
        kor
        nodeNames
        mkPkgs
        homeModule
        mkCriomOS
        mkWorld
        ;
      inherit (lib) optionalAttrs genAttrs hasAttr;

      criomOS =
        let
          cleanEvaluation = hasAttr "rev" self;
        in
        { inherit cleanEvaluation; } // optionalAttrs cleanEvaluation { inherit (self) shortRev rev; };

      mkPkgsAndWorldFromSystem =
        system:
        let
          pkgs = mkPkgs { inherit nixpkgs lib system; };
        in
        {
          inherit pkgs;
          world = mkWorld {
            inherit
              lib
              pkgs
              system
              hob
              localSources
              ;
          };
        };

      perSystemPkgsAndWorld = eachDefaultSystem mkPkgsAndWorldFromSystem;

      mkPkgsAndWorld = system: mapAttrs (name: value: value.${system}) perSystemPkgsAndWorld;

      inherit (builtins) mapAttrs;
      inherit (kor) archToSystemMap;
      inherit (flake-utils.lib) eachDefaultSystem;

      generateCrioSphereProposalFromName =
        name:
        let
          subCriomeConfig = inputs."${name}".NodeProposal or { };
          explicitNodes = subCriomeConfig.nodes or { };
          implicitNodes = import ./implicitNodes.nix;
          allNodes = explicitNodes // implicitNodes;
        in
        subCriomeConfig // { nodes = allNodes; };

      uncheckedCrioSphereProposal = genAttrs nodeNames generateCrioSphereProposalFromName;

      mkNodeDerivations =
        preNodeName: crioZone:
        let
          inherit (crioZone) users;
          inherit (crioZone.node.machine) arch;
          system = archToSystemMap.${arch};
          pkgsAndWorld = mkPkgsAndWorld system;
          inherit (pkgsAndWorld) pkgs world;
          horizon = crioZone;

          userProfiles = {
            light = {
              dark = false;
            };
            dark = {
              dark = true;
            };
          };

          mkUserHomes =
            userName: user:
            let
              inherit (world) pkdjz;

              mkProfileHom =
                profileName: profile:
                let
                  modules = [ homeModule ];
                  extraSpecialArgs = {
                    inherit
                      kor
                      pkdjz
                      world
                      horizon
                      user
                      profile
                      ;
                  };
                  evalHomeManager = hob.home-manager.lib.homeManagerConfiguration;
                  evaluation = evalHomeManager { inherit modules extraSpecialArgs pkgs; };
                in
                evaluation.config.home.activationPackage;
            in
            mapAttrs mkProfileHom userProfiles;

          mkUserEmacs =
            userName: user:
            let
              inherit (world.pkdjz) mkEmacs;
              mkProfileEmacs = profileName: profile: mkEmacs { inherit user profile; };
            in
            mapAttrs mkProfileEmacs userProfiles;

        in
        {
          os = mkCriomOS {
            inherit
              criomOS
              kor
              world
              horizon
              homeModule
              hob
              ;
          };
          hom = mapAttrs mkUserHomes users;
          emacs = mapAttrs mkUserEmacs users;
        };

      mkEachCrioZoneDerivations =
        crioZones:
        let
          mkNodeDerivationIndex = nodeName: nodePreNodeIndeks: mapAttrs mkNodeDerivations nodePreNodeIndeks;
        in
        mapAttrs mkNodeDerivationIndex crioZones;

      mkNixApiOutputsPerSystem =
        system:
        let
          pkgsAndWorld = mkPkgsAndWorld system;
          inherit (pkgsAndWorld) pkgs world;
          inherit (pkgs) symlinkJoin linkFarm;

          mkHobOutput =
            name: src:
            symlinkJoin {
              inherit name;
              paths = [ src.outPath ];
            };

          hobOutputs = mapAttrs mkHobOutput hob;

          mkSpokFarmEntry = name: spok: {
            inherit name;
            path = spok.outPath;
          };

          allMeinHobOutputs = linkFarm "hob" (kor.mapAttrsToList mkSpokFarmEntry hobOutputs);

        in
        {
          packages = world // {
            inherit pkgs;
            hob = hobOutputs;
            fullHob = allMeinHobOutputs;
          };
        };

      perSystemAllOutputs = eachDefaultSystem mkNixApiOutputsPerSystem;

      proposedCrioSphere = localSources.mkCrioSphere { inherit uncheckedCrioSphereProposal kor lib; };
      proposedCrioZones = localSources.mkCrioZones { inherit kor lib proposedCrioSphere; };

    in
    perSystemAllOutputs
    // {
      crioZones = mkEachCrioZoneDerivations proposedCrioZones;
    };

  inputs = {
    # Nixpkgs & lib
    nixpkgs.url = "github:criome/nixpkgs/testing";
    lib.url = "github:criome/lib";
    lib.inputs.nixpkgs.follows = "nixpkgs";

    # Nixpkgs overlays
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Horizon
    maisiliym.url = "github:LiGoldragon/maisiliym/testing";
    goldragon.url = "github:LiGoldragon/goldragon";
    seahawk.url = "github:criome/seahawk";

    # Todo - binary cache
    attic.url = "github:zhaofengli/attic";

    # Misc
    kibord.url = "github:LiGoldragon/kibord/testing";
    skrips.url = "github:criome/skrips/testing";

    # Websites - TODO: bad design
    mkZolaWebsite.url = "github:criome/mkZolaWebsite";
    goldragonWebsite = {
      url = "github:LiGoldragon/webpage";
      flake = false;
    };
    seahawkWebsite = {
      url = "github:AnaSeahawk/website";
      flake = false;
    };

    # pkdjz
    base16-styles = {
      url = "github:samme/base16-styles";
      flake = false;
    };
    base16-theme = {
      url = "github:league/base16-emacs";
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-registry = {
      url = "github:NixOS/flake-registry";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jujutsu-el = {
      url = "github:bennyandresen/jujutsu.el";
      flake = false;
    };
    lojix = {
      url = "github:criome/lojix";
      flake = false;
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        clj-nix.follows = "clj-nix";
      };
    };
    md-roam = {
      url = "github:nobiot/md-roam";
      flake = false;
    };
    mfgtools = {
      url = "github:NXPmicro/mfgtools";
      flake = false;
    };
    ndi = {
      url = "github:LiGoldragon/ndi";
      flake = false;
    };
    shen = {
      url = "github:criome/shen";
      flake = false;
    };
    shen-mode = {
      url = "github:NHALX/shen-mode";
      flake = false;
    };
    tera-mode = {
      url = "github:svavs/tera-mode";
      flake = false;
    };
    videocut = {
      url = "github:kanehekili/VideoCut";
      flake = false;
    };
    xah-fly-keys = {
      url = "github:xahlee/xah-fly-keys";
      flake = false;
    };
  };
}
