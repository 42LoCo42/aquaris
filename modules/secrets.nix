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
  inherit (types)
    attrsOf
    path
    str
    submodule;
  cfg = config.aquaris;
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
          name = mkOption {
            type = str;
            default = name;
          };

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

  config = {
    aquaris.secrets =
      let
        secrets = "${self}/secrets";
        strip = builtins.replaceStrings [ ".age" ] [ "" ];
        readDirMaybe = dir:
          if builtins.pathExists dir then builtins.readDir dir else { };

        toplevel = pipe secrets [
          readDirMaybe
          (filterAttrs (_: typ: typ == "regular"))
          (mapAttrs' (sec: _: {
            name = strip sec;
            value.source = "${secrets}/${sec}";
          }))
        ];

        collect = dir: out: cfg: pipe "${secrets}/${dir}" [
          readDirMaybe
          (mapAttrs' (sec: _: {
            name = strip "${out}/${sec}";
            value = cfg // { source = "${secrets}/${dir}/${sec}"; };
          }))
        ];

        machine = collect "machines/${cfg.machine.name}" "machine" { };

        user = pipe cfg.users [
          (mapAttrsToList (userN: userV:
            let d = "users/${userN}"; in collect d d { user = userV.name; }))
          mergeAttrsList
        ];
      in
      toplevel // machine // user;

    system.activationScripts =
      let d = "${cfg.secretsDir}.d/${baseNameOf self}"; in {
        aqs-install.text =
          pipe cfg.secrets [
            (mapAttrsToList (_: s:
              let o = "${d}/${s.name}"; in ''
                echo "[aqs] decrypting ${s.name}"
                mkdir -pv "${dirOf o}"
                ${getExe pkgs.age} -i "${cfg.machine.secretKey}" -o "${o}" -d "${s.source}"
              ''))
            concatLines
            (s: s + ''
              ln -sfT "${d}" "${cfg.secretsDir}"
            '')
          ];

        users.deps = [ "aqs-install" ];

        aqs-chown = {
          deps = [ "users" "groups" ];
          text = pipe cfg.secrets [
            (mapAttrsToList (_: s:
              let o = "${d}/${s.name}"; in ''
                echo "[aqs] ${s.name}: ${s.user}:${s.group} ${s.mode}"
                chown "${s.user}:${s.group}" "${o}"
                chmod "${s.mode}" "${o}"
              ''))
            concatLines
          ];
        };
      };
  };
}
