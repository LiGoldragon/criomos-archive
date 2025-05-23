{
  kor,
  lib,
  user,
  ...
}:
let
  inherit (kor) optional;

in
{
  config = {
    home = {
      username = user.name;
      homeDirectory = "/home/" + user.name;
      # TODO
      stateVersion = "23.11";
    };
  };
}
