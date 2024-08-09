{ self, aquaris, pkgs, lib, config, ... }:
let
  inherit (lib)
    concatLines
    filterAttrs
    flip
    getExe
    mapAttrs'
    mapAttrsToList
    mergeAttrsList
    mkOption
    pipe
    sourceFilesBySuffices
    ;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.types) attrsOf path str submodule;

  cfg = config.aquaris.secrets;

  decryptDir = "/run/aqs";
  secretsDir = (sourceFilesBySuffices "${self}/secrets" [ ".age" ]).outPath;
  outputDir = "${decryptDir}.d/${baseNameOf secretsDir}";
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

  ##########################################

  aqs = getExe (pkgs.writeShellApplication {
    name = "aqs";
    runtimeInputs = with pkgs; [ age findutils jq ];
    text = builtins.readFile ./aqs.sh;
  });

  secrets = pipe cfg [
    (builtins.mapAttrs (_: flip removeAttrs [ "outPath" ]))
    builtins.toJSON
    (pkgs.writeText "secrets.json")
  ];
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
      aqs-decrypt = ''
        ${aqs} decrypt  \
          ${secrets}    \
          ${secretKey}  \
          ${outputDir}  \
          ${decryptDir}
      '';

      users.deps = [ "aqs-decrypt" ];

      aqs-chown = {
        deps = [ "users" "groups" ];
        text = ''
          ${aqs} chown  \
            ${secrets}  \
            ${outputDir}
        '';
      };

      aqs-protect = ''
        ${aqs} protect \
          ${secretKey}
      '';
    };
  };
}
