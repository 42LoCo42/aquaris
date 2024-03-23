{ self, pkgs, config, lib, ... }:
let
  inherit (lib)
    concatLines
    filterAttrs
    getExe
    mapAttrs'
    mapAttrsToList
    mkOption
    pipe
    types;
  inherit (lib.attrsets) mergeAttrsList;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (types)
    attrsOf
    path
    str
    submodule;
  cfg = config.aquaris;

  notSAL = lib.mkIf (! cfg.standalone);
in
{
  options.aquaris = {
    secretsDir = mkOption {
      type = path;
      description = "Directory where secrets are decrypted to";
      default = "/run/secrets";
    };

    secrets = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          source = mkOption {
            type = path;
          };

          outPath = mkOption {
            type = path;
            default = "${cfg.secretsDir}/${name}";
          };

          user = mkOption {
            type = str;
            default = "root";
          };

          group = mkOption {
            type = str;
            default = "root";
          };

          mode = mkOption {
            type = str;
            default = "0400";
          };
        };
      }));
    };
  };

  config = notSAL {
    aquaris.secrets =
      let
        secrets = "${self}/secrets";
        maybePipe = dir: if builtins.pathExists dir then pipe dir else (_: { });

        collect = dir: group:
          let dir' = "${secrets}/${dir}"; in maybePipe dir' [
            listFilesRecursive
            (map (source: {
              name = group + builtins.replaceStrings [ dir' ".age" ] [ "" "" ]
                # listFilesRecursive adds context we don't need in a name
                (builtins.unsafeDiscardStringContext source);
              value = { inherit source; };
            }))
            builtins.listToAttrs
          ];

        toplevel = maybePipe secrets [
          builtins.readDir
          (filterAttrs (_: typ: typ == "regular"))
          (mapAttrs' (name: _: {
            name = builtins.replaceStrings [ ".age" ] [ "" ] name;
            value.source = "${secrets}/${name}";
          }))
        ];

        machine = collect "machines/${cfg.machine.name}" "machine";

        user = pipe cfg.users [
          builtins.attrNames
          (map (u: collect "users/${u}" "users/${u}"))
          mergeAttrsList
        ];
      in
      toplevel // machine // user;

    system.activationScripts =
      let d = "${cfg.secretsDir}.d/${baseNameOf self}"; in {
        aqs-install.text =
          pipe cfg.secrets [
            (mapAttrsToList (name: s:
              let o = "${d}/${name}"; in ''
                echo "[aqs] decrypting ${name}"
                mkdir -pv "${dirOf o}"
                (umask u=r,g=,o=; ${getExe pkgs.age} -i "${cfg.machine.secretKey}" -o "${o}" -d "${s.source}") &
              ''))
            concatLines
            (s: s + ''
              wait
              ln -sfT "${d}" "${cfg.secretsDir}"
            '')
          ];

        users.deps = [ "aqs-install" ];

        aqs-chown = {
          deps = [ "users" "groups" ];
          text = pipe cfg.secrets [
            (mapAttrsToList (name: s:
              let o = "${d}/${name}"; in ''
                echo "[aqs] ${name}: ${s.user}:${s.group} ${s.mode}"
                chown "${s.user}:${s.group}" "${o}"
                chmod "${s.mode}" "${o}"
              ''))
            concatLines
          ];
        };
      };
  };
}
