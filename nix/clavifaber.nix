{ pkgs }:

let
  clavifaber-unwrapped = pkgs.rustPlatform.buildRustPackage {
    pname = "clavifaber";
    version = "0.1.0";
    src = ../src/clavifaber;
    cargoLock.lockFile = ../src/clavifaber/Cargo.lock;
  };
in
pkgs.symlinkJoin {
  name = "clavifaber-0.1.0";
  paths = [ clavifaber-unwrapped ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/clavifaber \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.gnupg
      ]}
  '';
}
