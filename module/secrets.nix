{ self, aquaris, pkgs, lib, config, ... }:
let
  inherit (lib)
    concatLines
    filterAttrs
    getExe
    mapAttrs'
    mapAttrsToList
    mergeAttrsList
    mkOption pipe
    ;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.types) attrsOf path str submodule;

  cfg = config.aquaris.secrets;

  decryptDir = "/run/aqs";
  outputDir = "${decryptDir}.d/${baseNameOf self}";
  secretsDir = "${self}/secrets";
  inherit (config.aquaris.machine) secretKey;

  ##########################################

  maybePipe = dir: if builtins.pathExists dir then pipe dir else (_: { });

  collect = dir: group:
    let dir' = "${secretsDir}/${dir}"; in maybePipe dir' [
      listFilesRecursive
      (map (source: {
        name = group + builtins.replaceStrings [ dir' ".age" ] [ "" "" ]
          # listFilesRecursive adds context we don't need in a name
          (builtins.unsafeDiscardStringContext source);
        value = { inherit source; };
      }))
      builtins.listToAttrs
    ];

  toplevel = maybePipe secretsDir [
    builtins.readDir
    (filterAttrs (_: typ: typ == "regular"))
    (mapAttrs' (name: _: {
      name = builtins.replaceStrings [ ".age" ] [ "" ] name;
      value.source = "${secretsDir}/${name}";
    }))
  ];

  machine = collect "machines/${aquaris.name}" "machine";

  user = pipe config.aquaris.users [
    builtins.attrNames
    (map (u: collect "users/${u}" "users/${u}"))
    mergeAttrsList
  ];

  aqs-decrypt = pkgs.writeShellApplication {
    name = "aqs-decrypt";
    runtimeInputs = with pkgs; [ age findutils ];
    text = pipe cfg [
      (mapAttrsToList (name: s:
        let o = "${outputDir}/${name}"; in ''
          echo "[aqs] decrypting ${name}"
          mkdir -p "${dirOf o}"
          (umask u=r,g=,o=; age \
            -i "${secretKey}"   \
            -o "${o}"           \
            -d "${s.source}") &
        ''))
      concatLines
      (x: x + ''
        wait
        ln -sfT "${outputDir}" "${decryptDir}"

        echo "[aqs] collecting garbage"
        find "${decryptDir}.d" -mindepth 1 -maxdepth 1 \
        | { grep -v "${decryptDir}" || :; }            \
        | xargs rm -rfv
      '')
    ];
  };

  aqs-chown = pkgs.writeShellApplication {
    name = "aqs-chown";
    text = pipe cfg [
      (mapAttrsToList (name: s:
        let o = "${outputDir}/${name}"; in ''
          echo "[aqs] ${name}: ${s.user}:${s.group} ${s.mode}"
          chown "${s.user}:${s.group}" "${o}"
          chmod "${s.mode}" "${o}"
        ''))
      concatLines
    ];
  };
in
{
  options.aquaris.secrets = mkOption {
    description = "Set of available secrets";
    type = attrsOf (submodule ({ name, ... }: {
      options = {
        source = mkOption {
          description = "Path of the encrypted secret file";
          type = path;
        };

        outPath = mkOption {
          description = "Path of the decrypted secret file";
          type = path;
          default = "${decryptDir}/${name}";
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
    aquaris.secrets = toplevel // machine // user;

    system.activationScripts = {
      aqs-decrypt = getExe aqs-decrypt;

      users.deps = [ "aqs-decrypt" ];

      aqs-chown = {
        deps = [ "users" "groups" ];
        text = getExe aqs-chown;
      };
    };
  };
}
