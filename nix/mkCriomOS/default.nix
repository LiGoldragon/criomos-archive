{
  criomOS,
  homeModule,
  kor,
  world,
  horizon,
  hob,
}:
let
  inherit (kor) optional;
  inherit (world) pkdjz home-manager;
  inherit (pkdjz) evalNixos;
  inherit (horizon.astra) machine io typeIs;

  usePodModule = (machine.species == "pod");
  useMetylModule = (machine.species == "metyl");

  useRouterModule = typeIs.haibrid || typeIs.router;
  useEdjModule = typeIs.edj || typeIs.haibrid || typeIs.edjTesting;
  useIsoModule = !usePodModule && (io.disks == { });

  usersModule = import ./users.nix;
  niksModule = import ./niks.nix;
  normylaizModule = import ./normylaiz.nix;
  networkModule = import ./network;
  edjModule = import ./edj;

  disksModule =
    if usePodModule then
      import ./pod.nix
    else if useIsoModule then
      import ./liveIso.nix
    else
      import ./priInstyld.nix;

  metylModule = import ./metyl;

  beisModules = [
    usersModule
    disksModule
    niksModule
    normylaizModule
    networkModule
  ];

  nixosModules =
    beisModules
    ++ (optional useEdjModule edjModule)
    ++ (optional useRouterModule ./router)
    ++ (optional useIsoModule home-manager.nixosModules.default)
    ++ (optional useMetylModule metylModule);

  nixosArgs = {
    inherit
      kor
      world
      pkdjz
      horizon
      criomOS
      homeModule
      hob
      ;
    konstynts = import ./konstynts.nix;
  };

  evaluation = evalNixos {
    inherit useIsoModule;
    moduleArgs = nixosArgs;
    modules = nixosModules;
  };

  bildNiksOSVM = evaluation.config.system.build.vm;
  bildNiksOSIso = evaluation.config.system.build.isoImage;
  bildNiksOS = evaluation.config.system.build.toplevel;

in
if useIsoModule then bildNiksOSIso else bildNiksOS
