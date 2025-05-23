{
  kor,
  lib,
  proposedCrioSphere,
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib) evalModules;

  metastriz = proposedCrioSphere;

  hyraizynOptions = import ./hyraizynOptions.nix;
  mkHyraizynModule = import ./mkHyraizynModule.nix;

  mkCrioZone =
    clusterName: astraName:
    let
      argzModule = {
        config = {
          inherit astraName clusterName;
          _module.args = {
            inherit kor lib;
            Metastriz = metastriz.datom;
            metastrizSpiciz = metastriz.spiciz;
          };
        };
      };

      ivaliueicyn = evalModules {
        modules = [
          argzModule
          hyraizynOptions
          mkHyraizynModule
        ];
      };

      crioZone = ivaliueicyn.config.hyraizyn;

    in
    crioZone;

  mkNeksysCrioZones = neksysName: neksys: mapAttrs (pnn: pn: mkCrioZone neksysName pnn) neksys.astriz;

  ryzylt = mapAttrs mkNeksysCrioZones proposedCrioSphere.datom;

in
ryzylt
