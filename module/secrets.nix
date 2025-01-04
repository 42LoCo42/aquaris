{ aquaris, self, pkgs, lib, config, ... }:
let
  inherit (lib)
    filterAttrs
    mkDefault
    flip
    getExe
    mapAttrsToList
    mapNullable
    mkOption
    pipe
    ;
  inherit (lib.types)
    attrsOf
    nullOr
    path
    str
    submodule
    ;

  cfg = config.aquaris.secrets;

  secretsFile = builtins.path { path = "${self.cfgDir}/sesi.yaml"; };
  decryptDirTop = "/run/secrets";
  decryptDirMnt = "${decryptDirTop}.d";
  decryptDirOut = "${decryptDirMnt}/${builtins.hashFile "sha256" secretsFile}";

  machine = "machine:${aquaris.name}";
  machineKey = config.aquaris.machine.key;
  sillysecrets = aquaris.inputs.obscura.packages.${pkgs.system}.sillysecrets;

  toPath = name: "${decryptDirTop}/${builtins.replaceStrings ["."] ["/"] name}";

  toAlias = builtins.replaceStrings [ machine ":" "." ] [ "machine" "/" "/" ];

  toUser = name: pipe name [
    (builtins.match "user:([^.]+).*")
    (mapNullable builtins.head)
    (x: if x == null then "root" else x)
  ];

  secrets = pipe secretsFile [
    (x: (pkgs.runCommand "secrets" {
      nativeBuildInputs = [ sillysecrets ];
    }) "sesi -f ${x} list ${machine} > $out")
    aquaris.lib.readLines

    (x:
      let
        originals = (flip map x) (name: {
          inherit name;
          value = {
            outPath = toPath name;
            alias = null;
            user = mkDefault (toUser name);
          };
        });

        aliases = (flip map x) (name: {
          name = toAlias name;
          value = {
            outPath = toPath (toAlias name);
            alias = toPath name;
            user = null;
          };
        });
      in
      [ originals aliases ])

    (map builtins.listToAttrs)
    aquaris.lib.merge
  ];

  onlyNull = {
    description = "only null";
    deprecationMessage = null;

    check = x: x == null;
    merge = _: _: null;
  };

  script = args: getExe (pkgs.writeShellApplication args);
in
{
  options.aquaris.secrets = mkOption {
    description = "Set of available secrets";
    type = attrsOf (submodule ({ name, config, ... }:
      let isAlias = config.alias != null; in {
        options = {
          outPath = mkOption {
            description = "Path of the decrypted secret file";
            type = path;
            default = "${decryptDirTop}/${name}";
          };

          alias = mkOption {
            description = "Is this entry an alias?";
            type = nullOr path;
            readOnly = true;
          };

          user = mkOption {
            description = "User that owns the decrypted secret file";
            type = if isAlias then onlyNull else str;
            # default: set in secrets importer
            readOnly = isAlias;
          };

          group = mkOption {
            description = "Group of the decrypted secret file";
            type = if isAlias then onlyNull else str;
            default = if isAlias then null else "root";
            readOnly = isAlias;
          };

          mode = mkOption {
            description = "Access mode of the decrypted secret file";
            type = if isAlias then onlyNull else str;
            default = if isAlias then null else "0400";
            readOnly = isAlias;
          };
        };
      }));
  };

  config = {
    aquaris = { inherit secrets; };

    security.pam.u2f.settings = {
      authfile = "${decryptDirTop}/user/%u/u2f-keys";
      expand = true;
    };

    environment.systemPackages = [ sillysecrets ];

    boot.initrd.systemd.mounts = [{
      before = [ "initrd-fs.target" ];
      requiredBy = [ "initrd-fs.target" ];

      type = "ramfs";
      what = "ramfs";
      where = "/sysroot${decryptDirMnt}";
    }];

    systemd.services = {
      secrets-decrypt = {
        before = [ "sysinit-reactivation.target" "userborn.service" ];
        wantedBy = [ "sysinit-reactivation.target" "userborn.service" ];

        unitConfig.DefaultDependencies = false;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = script {
            name = "secrets-decrypt";
            runtimeInputs = [ sillysecrets ];
            text = ''
              mkdir -p ${decryptDirOut}

              sesi -f ${secretsFile} -i ${machineKey} \
                decryptall ${machine} ${decryptDirOut}

              ln -sfT ${decryptDirOut} ${decryptDirTop}

              find ${decryptDirMnt}          \
                -mindepth 1 -maxdepth 1      \
                -not -path ${decryptDirOut}  \
                -exec rm -rfv {} \;
            '' + pipe cfg [
              (filterAttrs (_: v: v.alias != null))
              (mapAttrsToList (n: v: ''
                echo "${v} -> ${v.alias}"
                mkdir -p "$(dirname ${v})"
                ln -sf ${v.alias} ${v}
              ''))
              (builtins.concatStringsSep "")
            ];
          };
        };
      };

      secrets-chown = {
        after = [ "userborn.service" ];
        wants = [ "userborn.service" ];

        wantedBy = [ "sysinit.target" ];

        unitConfig.DefaultDependencies = false;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = script {
            name = "secrets-chown";
            text = pipe cfg [
              (filterAttrs (_: v: v.alias == null))
              (mapAttrsToList (n: v: ''
                echo "${n}: ${v.user}:${v.group} ${v.mode}"

                chmod 0755 "$(dirname ${v.outPath})"

                chown ${v.user}:${v.group} ${v.outPath}
                chmod ${v.mode}            ${v.outPath}
              ''))
              (builtins.concatStringsSep "")
            ];
          };
        };
      };
    };
  };
}
