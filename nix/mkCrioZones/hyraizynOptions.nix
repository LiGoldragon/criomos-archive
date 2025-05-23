{
  config,
  lib,
  metastrizSpiciz,
  ...
}:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    enum
    str
    attrsOf
    submodule
    nullOr
    bool
    int
    listOf
    attrs
    ;

  inherit (metastrizSpiciz)
    metastriNames
    astriSpiciz
    magnytiud
    sistymz
    komynUserOptions
    mycinSpici
    IoOptions
    ;

  astriOptions = {
    name = mkOption {
      type = str;
    };

    spici = mkOption {
      type = enum astriSpiciz;
      default = "sentyr";
    };

    trost = mkOption {
      type = enum magnytiud;
    };

    criomOSName = mkOption {
      type = str;
    };

    sistym = mkOption {
      type = enum sistymz;
    };

    nbOfBildKorz = mkOption {
      type = int;
      default = 1;
    };

    saiz = mkOption {
      type = enum magnytiud;
    };

    mycin = mkOption {
      type = mycinSpici;
    };

    yggPreCriome = mkOption {
      type = nullOr str;
      default = null;
    };

    yggAddress = mkOption {
      type = nullOr str;
      default = null;
    };

    yggSubnet = mkOption {
      type = nullOr str;
      default = null;
    };

    eseseitc = mkOption {
      type = nullOr str;
      default = null;
    };

    niksPreCriome = mkOption {
      type = nullOr str;
      default = null;
    };

    linkLocalIPs = mkOption {
      type = listOf str;
      default = [ ];
    };

    neksysIp = mkOption {
      type = nullOr str;
      default = null;
    };

    wireguardPreCriome = mkOption {
      type = nullOr str;
      default = null;
    };

    wireguardUntrustedProxies = mkOption {
      type = listOf attrs;
      default = [ ];
    };

    methods = mkOption {
      type = attrs;
      default = { };
    };

    typeIs = mkOption {
      type = attrs;
      default = { };
    };
  };

  clusterSubmodule = {
    options = {
      name = mkOption {
        type = enum metastriNames;
      };

      methods = mkOption {
        type = attrs;
        default = { };
      };
    };
  };

  astraOptions = astriOptions // {
    io = mkOption {
      type = submodule { options = IoOptions; };
      default = { };
    };
  };

  userSubmodule = {
    options = komynUserOptions // {
      name = mkOption {
        type = str;
      };

      trost = mkOption {
        type = enum magnytiud;
      };

      methods = mkOption {
        type = attrs;
        default = { };
      };
    };
  };

  hyraizynOptions = {
    options = {
      cluster = mkOption {
        type = submodule clusterSubmodule;
      };

      astra = mkOption {
        type = submodule { options = astraOptions; };
      };

      exAstriz = mkOption {
        type = attrsOf (submodule {
          options = astriOptions;
        });
      };

      users = mkOption {
        type = attrsOf (submodule userSubmodule);
      };

      methods = mkOption {
        type = attrs;
        default = { };
      };
    };
  };

in
{
  options = {
    hyraizyn = mkOption {
      type = submodule hyraizynOptions;
    };

    astraName = mkOption {
      type = str;
    };

    clusterName = mkOption {
      type = str;
    };

  };

}
