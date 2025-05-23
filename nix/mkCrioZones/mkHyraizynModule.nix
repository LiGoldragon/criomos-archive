{
  lib,
  config,
  kor,
  metastrizSpiciz,
  Metastriz,
  ...
}:
let
  inherit (builtins)
    filter
    concatStringsSep
    listToAttrs
    hasAttr
    attrNames
    concatMap
    elem
    ;
  inherit (kor)
    louestOf
    nameValuePair
    filterAttrs
    spiciDatum
    optional
    mapAttrsToList
    optionalAttrs
    optionalString
    arkSistymMap
    unique
    ;
  inherit (config) clusterName astraName spiciz;
  inherit (metastrizSpiciz) metastriNames astriSpiciz;

  inputCluster = Metastriz.${clusterName};
  inputAstriz = inputCluster.astriz;
  inputAstra = inputAstriz.${astraName};

  astriNames = attrNames inputCluster.astriz;
  userNames = attrNames inputCluster.users;

  neksysCriomOSName = concatStringsSep "." [
    clusterName
    "criome"
  ];

  metaTrost = inputCluster.trost.cluster;

  mkTrost = yrei: louestOf (yrei ++ [ metaTrost ]);

  mkEseseitcString =
    preCriome:
    if (preCriome == null) then
      ""
    else
      concatStringsSep " " [
        "ssh-ed25519"
        preCriome
      ];

  mkAstri =
    astriName:
    let
      # (TODO typecheck)
      inputAstri = inputAstriz.${astriName};
      inherit (inputAstri) saiz spici;
      inherit (inputAstri.preCriomes) yggdrasil;

      filteredMycin = spiciDatum {
        datum = inputAstri.mycin;
        spek = {
          metyl = [
            "ark"
            "mothyrBord"
            "modyl"
          ];
          pod = [
            "ark"
            "ubyrAstri"
            "ubyrUser"
          ];
        };
      };

      rytyrnArkFromMothyrBord = mb: abort "Missing mothyrBord table";

      tcekdArk =
        if (filteredMycin.ark != null) then
          filteredMycin.ark
        else if (filteredMycin.spici == "pod") then
          astriz.${filteredMycin.ubyrAstri}.mycin.ark
        else if (filteredMycin.mothyrBord != null) then
          (rytyrnArkFromMothyrBord filteredMycin.mothyrBord)
        else
          abort "Missing mycin ark";

      mycin = filteredMycin // {
        ark = tcekdArk;
      };

      mkLinkLocalIP =
        linkLocalIP:
        with linkLocalIP;
        let
          interface = if (spici == "ethernet") then "enp0s25" else "wlp3s0";
        in
        "fe80::${suffix}%${interface}";

      neksysIp = inputAstri.neksysIp or null;
      wireguardPreCriome = inputAstri.wireguardPreCriome or null;

      mkTypeIsFromTypeName =
        name:
        let
          isOfThisType = name == spici;
        in
        nameValuePair name isOfThisType;

      astri = {
        inherit saiz spici;

        name = astriName;
        inherit mycin wireguardPreCriome neksysIp;

        linkLocalIPs =
          if (hasAttr "linkLocalIPs" inputAstri) then (map mkLinkLocalIP inputAstri.linkLocalIPs) else [ ];

        trost = mkTrost [
          inputAstri.trost
          inputCluster.trost.astriz.${astriName}
        ];

        eseseitc = mkEseseitcString inputAstri.preCriomes.eseseitc;

        yggPreCriome = yggdrasil.preCriome;
        yggAddress = yggdrasil.address;
        yggSubnet = yggdrasil.subnet;

        inherit (inputAstri.preCriomes) niksPreCriome;

        criomOSName = concatStringsSep "." [
          astriName
          neksysCriomOSName
        ];

        sistym = arkSistymMap.${mycin.ark};

        nbOfBildKorz = 1; # TODO

        typeIs = listToAttrs (map mkTypeIsFromTypeName astriSpiciz);
      };

      methods =
        let
          inherit (astri)
            spici
            trost
            saiz
            niksPreCriome
            yggAddress
            criomOSName
            typeIs
            ;

        in
        rec {
          isFullyTrusted = trost == 3;
          sizedAtLeast = kor.mkSaizAtList saiz;
          isBuilder = !typeIs.edj && isFullyTrusted && (sizedAtLeast.med || typeIs.sentyr) && hasBasePrecriads;
          isDispatcher = !typeIs.sentyr && isFullyTrusted && sizedAtLeast.min;
          isNixCache = typeIs.sentyr && sizedAtLeast.min && hasBasePrecriads;
          izNiksCriodaizd = niksPreCriome != null && niksPreCriome != "";
          hasYggPrecriad = yggAddress != null && yggAddress != "";
          izNeksisCriodaizd = hasYggPrecriad;
          hasSshPrecriad = hasAttr "eseseitc" inputAstri.preCriomes;
          hasWireguardPrecriad = wireguardPreCriome != null;

          hasBasePrecriads = izNiksCriodaizd && hasYggPrecriad && hasSshPrecriad;

          sshPrecriome =
            if !hasSshPrecriad then "" else mkEseseitcString inputAstri.preCriomes.eseseitc;

          nixPreCriome = optionalString izNiksCriodaizd (
            concatStringsSep ":" [
              criomOSName
              niksPreCriome
            ]
          );

          nixCacheDomain = if isNixCache then ("nix." + criomOSName) else null;
          nixUrl = if isNixCache then ("http://" + nixCacheDomain) else null;

        };

    in
    astri // { inherit methods; };

  exAstriNames = attrNames exAstriz;
  bildyrz = filter (n: astriz.${n}.methods.isBuilder) exAstriNames;
  kacyz = filter (n: astriz.${n}.methods.isNixCache) exAstriNames;
  dispatcyrz = filter (n: astriz.${n}.methods.isDispatcher) exAstriNames;

  adminUserNames = filter (n: users.${n}.trost == 3) userNames;

  astraMethods =
    let
      mkBildyr =
        n:
        let
          astri = exAstriz.${n};
        in
        {
          hostName = astri.criomOSName;
          sshUser = "nixBuilder";
          sshKey = "/etc/ssh/ssh_host_ed25519_key";
          supportedFeatures = optional (!astri.typeIs.edj) "big-parallel";
          system = astri.sistym;
          systems = lib.optional (astri.sistym == "x86_64-linux") "i686-linux";
          maxJobs = astri.nbOfBildKorz;
        };

      mkAdminUserPreCriomes =
        adminUserName:
        let
          adminUser = users.${adminUserName};
          preCriomeAstriNames = attrNames adminUser.preCriomes;
          izAstriFulyTrostyd = n: astriz.${n}.methods.isFullyTrusted;
          fulyTrostydPreCriomeNames = filter izAstriFulyTrostyd preCriomeAstriNames;
          getEseseitcString =
            n:
            if (adminUser.preCriomes.${n}.eseseitc == null) then
              ""
            else
              (mkEseseitcString adminUser.preCriomes.${n}.eseseitc);
        in
        map getEseseitcString fulyTrostydPreCriomeNames;

      inherit (astra.mycin) modyl;
      thinkpadModylz = [
        "ThinkPadX240"
        "ThinkPadX230"
      ];
      impozdHTModylz = [ "ThinkPadX240" ];

      computerModylz = thinkpadModylz ++ [ "rpi3B" ];

      computerIsNotMap = listToAttrs (map (n: nameValuePair n false) computerModylz);

    in
    {
      bildyrKonfigz = map mkBildyr bildyrz;

      kacURLz =
        let
          mkKacURL = n: exAstriz.${n}.methods.nixUrl;
        in
        map mkKacURL kacyz;

      exAstrizEseseitcPreCriomes = map (n: exAstriz.${n}.eseseitc) exAstriNames;

      dispatcyrzEseseitcKiz = map (n: exAstriz.${n}.eseseitc) dispatcyrz;

      adminEseseitcPreCriomes = unique (concatMap mkAdminUserPreCriomes adminUserNames);

      tcipIzIntel = elem astra.mycin.ark [
        "x86-64"
        "i686"
      ]; # TODO

      modylIzThinkpad = elem astra.mycin.modyl thinkpadModylz;

      impozyzHaipyrThreding = elem astra.mycin.modyl impozdHTModylz;

      iuzColemak = astra.io.kibord == "colemak";

      computerIs = computerIsNotMap // (optionalAttrs (modyl != null) { "${modyl}" = true; });

      wireguardUntrustedProxies = astra.wireguardUntrustedProxies or [ ];
    };

  mkUser =
    userName:
    let
      inputUser = inputCluster.users.${userName};

      tcekPreCriome = astriName: preCriome: hasAttr astriName astriz;

      user = {
        name = userName;

        inherit (inputUser) stail spici kibord;

        saiz = louestOf [
          inputUser.saiz
          astra.saiz
        ];

        trost = inputCluster.trost.users.${userName};

        preCriomes = filterAttrs tcekPreCriome inputUser.preCriomes;

        githubId = if (inputUser.githubId == null) then userName else inputUser.githubId;

      };

      hazPreCriome = hasAttr astra.name user.preCriomes;

      methods =
        {
          inherit hazPreCriome;

          sizedAtLeast = kor.mkSaizAtList user.saiz;

          emailAddress = "${user.name}@${cluster.name}.criome.me";
          matrixID = "@${user.name}:${cluster.name}.criome.me";

          gitSigningKey = if hazPreCriome then ("&" + user.preCriomes.${astra.name}.keygrip) else null;

          iuzColemak = user.kibord == "colemak";

          izSemaDev = elem user.spici [
            "Sema"
            "Onlimityd"
          ];
          izNiksDev = elem user.spici [
            "Niks"
            "Onlimityd"
          ];

          eseseitcyz = mapAttrsToList (n: pk: mkEseseitcString pk.eseseitc) user.preCriomes;

        }
        // (kor.optionalAttrs hazPreCriome {
          eseseitc = mkEseseitcString user.preCriomes.${astra.name}.eseseitc;
        });

    in
    user // { inherit methods; };

  astriz = listToAttrs (
    map (y: nameValuePair y.name y) (filter (x: x.trost != 0) (map (n: mkAstri n) astriNames))
  );

  cluster = {
    name = clusterName;

    methods = {
      trostydBildPreCriomes = map (n: astriz.${n}.methods.nixPreCriome) astriNames;
    };
  };

  exAstriz = kor.filterAttrs (n: v: n != astraName) astriz;

  astra =
    let
      astri = astriz.${astraName};
    in
    astri
    // {
      inherit (inputAstra) io;
      methods = astri.methods // astraMethods;
    };

  users = listToAttrs (
    map (y: nameValuePair y.name y) (filter (x: x.trost != 0) (map (n: mkUser n) userNames))
  );

in
{
  hyraizyn = {
    inherit
      cluster
      astra
      exAstriz
      users
      ;
  };
}
