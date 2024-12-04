{ aquaris, self, pkgs, lib, config, ... }:
let
  inherit (lib)
    flip
    getExe
    mapAttrsToList
    mkOption
    pipe
    ;
  inherit (lib.types)
    attrsOf
    path
    str
    submodule
    ;

  secretsFile = "${self}/sesi.yaml";
  decryptDirTop = "/run/secrets";
  decryptDirMnt = "${decryptDirTop}.d";
  decryptDirOut = "${decryptDirMnt}/${builtins.hashFile "sha256" secretsFile}";

  machine = "machine:${aquaris.name}";
  machineKey = config.aquaris.machine.key;
  sillysecrets = aquaris.inputs.sillysecrets.packages.${pkgs.system}.default;

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
          value.outPath = toPath name;
        });

        aliases = (flip map x) (name: {
          name = builtins.replaceStrings
            [ machine ":" "." ] [ "machine" "/" "/" ]
            name;
          value.outPath = toPath name;
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
    type = attrsOf (submodule ({ name, ... }: {
      options = {
        outPath = mkOption {
          description = "Path of the decrypted secret file";
          type = path;
          default = "${decryptDirTop}/${name}";
        };

        user = mkOption {
          description = "User that owns the decrypted secret file";
          type = str;
          default = "root";
        };

        group = mkOption {
          description = "Group of the decrypted secret file";
          type = str;
          default = "root";
        };

        mode = mkOption {
          description = "Access mode of the decrypted secret file";
          type = str;
          default = "0400";
        };
      };
    }));
  };

  config = {
    aquaris = { inherit secrets; };

    # ramfs == tmpfs except it's never swapped to disk
    # fileSystems.${decryptDirMnt}.fsType = "ramfs";

    system.activationScripts = {
      secrets-decrypt = script {
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

      users.deps = [ "secrets-decrypt" ];

      secrets-chown = script {
        name = "secrets-chown";
        text = pipe config.aquaris.secrets [
          (mapAttrsToList (_: v: ''
            chmod 0755 "$(dirname ${v.outPath})"

            chown ${v.user}:${v.group} ${v.outPath}
            chmod ${v.mode}            ${v.outPath}
          ''))
          (builtins.concatStringsSep "")
        ];
      };

      machine-key-protect = ''
        chown root:root ${machineKey}
        chmod 0400      ${machineKey}
      '';
    };
  };
}
