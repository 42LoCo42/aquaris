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

          perms = mkOption {
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

    system.activationScripts.aquaris-secrets.text =
      let d = "${cfg.secretsDir}.d/${baseNameOf self}"; in
      pipe cfg.secrets [
        (mapAttrsToList (_: s:
          let o = "${d}/${s.name}"; in ''
            mkdir -pv "${dirOf o}"
            echo "[aqs] ${s.name}: ${s.user}:${s.group} ${s.perms}"
            ${getExe pkgs.age} -i "${cfg.machine.secretKey}" -o "${o}" -d "${s.source}"
            chown "${s.user}:${s.group}" "${o}"
            chmod "${s.perms}" "${o}"
          ''))
        concatLines
        (s: "set -e\n" + s + ''
          ln -sfT "${d}" "${cfg.secretsDir}"
        '')
      ];
  };
}
