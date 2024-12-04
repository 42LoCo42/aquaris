{ aquaris, self, pkgs, lib, config, ... }:
let
  inherit (lib)
    filterAttrs
    flip
    getExe
    mapAttrsToList
    mkOption
    pipe
    ;
  inherit (lib.types)
    bool
    attrsOf
    path
    str
    submodule
    ;

  cfg = config.aquaris.secrets;

  secretsFile = "${self.cfgDir}/sesi.yaml";
  decryptDirTop = "/run/secrets";
  decryptDirMnt = "${decryptDirTop}.d";
  decryptDirOut = "${decryptDirMnt}/${builtins.hashFile "sha256" secretsFile}";

  machine = "machine:${aquaris.name}";
  machineKey = config.aquaris.machine.key;
  sillysecrets = aquaris.inputs.obscura.packages.${pkgs.system}.sillysecrets;

  secrets = pipe secretsFile [
    (x: (pkgs.runCommand "secrets" {
      nativeBuildInputs = [ sillysecrets ];
    }) "sesi -f ${x} list ${machine} > $out")
    aquaris.lib.readLines

    (x:
      let
        toPath = name: "${decryptDirTop}/${builtins.replaceStrings ["."] ["/"] name}";

        originals = (flip map x) (name: {
          inherit name;
          value = {
            outPath = toPath name;
            alias = false;
          };
        });

        aliases = (flip map x) (name: {
          name = builtins.replaceStrings
            [ machine ":" "." ] [ "machine" "/" "/" ]
            name;
          value = {
            outPath = toPath name;
            alias = true;
          };
        });
      in
      [ originals aliases ])

    (map builtins.listToAttrs)
    aquaris.lib.merge
  ];

  script = args: getExe (pkgs.writeShellApplication args);
in
{
  options.aquaris.secrets = mkOption {
    description = "Set of available secrets";
    type = attrsOf (submodule ({ name, config, ... }: {
      options = {
        outPath = mkOption {
          description = "Path of the decrypted secret file";
          type = path;
          default = "${decryptDirTop}/${name}";
        };

        alias = mkOption {
          description = "Is this entry an alias?";
          type = bool;
          readOnly = true;
        };

        user = mkOption {
          description = "User that owns the decrypted secret file";
          type = str;
          default = if config.alias then "" else "root";
          readOnly = config.alias;
        };

        group = mkOption {
          description = "Group of the decrypted secret file";
          type = str;
          default = if config.alias then "" else "root";
          readOnly = config.alias;
        };

        mode = mkOption {
          description = "Access mode of the decrypted secret file";
          type = str;
          default = if config.alias then "" else "0400";
          readOnly = config.alias;
        };
      };
    }));
  };

  config = {
    aquaris = { inherit secrets; };

    systemd = {
      mounts = [{
        type = "ramfs";
        what = "ramfs";
        where = decryptDirMnt;
      }];

      services = {
        secrets-decrypt = {
          after = [ "run-secrets.d.mount" ];
          bindsTo = [ "run-secrets.d.mount" ];

          before = [ "userborn.service" ];
          wantedBy = [ "userborn.service" ];

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
                  -exec echo rm -rfv {} \;
              '';
            };
          };
        };

        secrets-chown = {
          after = [ "secrets-decrypt.service" ];
          wants = [ "secrets-decrypt.service" ];

          wantedBy = [ "sysinit.target" ];

          unitConfig.DefaultDependencies = false;

          serviceConfig.ExecStart = script {
            name = "secrets-chown";
            text = pipe cfg [
              (filterAttrs (_: v: !v.alias))
              (mapAttrsToList (_: v: ''
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
