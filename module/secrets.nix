{ aquaris, self, pkgs, lib, config, ... }:
let
  inherit (lib)
    concatLines
    filterAttrs
    flip
    getExe
    hasPrefix
    mapAttrsToList
    mkIf
    mkOption
    pipe
    removePrefix
    ;
  inherit (lib.types)
    attrsOf
    bool
    functionTo
    listOf
    path
    str
    submodule
    ;

  inherit (aquaris.inputs.obscura.packages.${pkgs.system}) sillysecrets;

  cfg = config.aquaris.secrets;

  storageFile = builtins.path { path = "${self.cfgDir}/sesi.json"; };
  structureFile = builtins.path { path = "${self.cfgDir}/sesi.yaml"; };

  structure = pipe structureFile [
    (x: (pkgs.runCommand "structure" {
      nativeBuildInputs = with pkgs; [ yq ];
    }) "yq < ${x} > $out")
    builtins.readFile
    builtins.fromJSON
  ];

  decryptDirTop = cfg.directory;
  decryptDirMnt = "${dirOf decryptDirTop}/.${baseNameOf decryptDirTop}.d";
  decryptDirOut = "${decryptDirMnt}/${builtins.hashFile "sha256" storageFile}";

  machineDst = "machine/${aquaris.name}";
  machineLnk = "@machine";

  accessor = checked: mkOption {
    type = functionTo path;
    readOnly = true;
    default = if !cfg.enable then _: "/dev/null" else
    name:
    if checked && !(builtins.elem name cfg.all)
    then abort "`${name}` is not a defined secret!"
    else "${decryptDirTop}/${name}";
  };

  ruleCfg = pipe cfg.rules [
    (mapAttrsToList (name: cfg:
      "z ${decryptDirTop}/${name} ${cfg.mode} ${cfg.user} ${cfg.group}"))
    (x: x ++ [ "z ${cfg.key} 0400 0 0" ])
    concatLines
    (pkgs.writeText "secrets-access-rules.conf")
  ];
in
{
  options.aquaris = {
    secret = accessor true;
    secret' = accessor false;

    secrets = {
      enable = mkOption {
        description = "Enable the secrets management module";
        type = bool;
        default = true;
      };

      pub = mkOption {
        description = ''
          Public key of this machine.
          If unspecified, will be read using IFD from the structure file.
        '';
        type = str;
        default = if !cfg.enable then "" else structure.machine.${aquaris.name}.":key";
      };

      key = mkOption {
        description = "Path to the key for decrypting secrets.";
        type = path;
        default = "${config.aquaris.persist.root}/var/lib/machine.key";
      };

      directory = mkOption {
        description = ''
          Secrets output directory
          (actual directory will be <this>.d/<sha56 of sesi.yaml>)
        '';
        type = path;
        default = "/run/secrets";
      };

      rules = mkOption {
        description = "Custom access rules for secrets";
        type = attrsOf (submodule {
          options = {
            user = mkOption {
              description = "User of the secret";
              type = str;
              default = "root";
            };

            group = mkOption {
              description = "Group of the secret";
              type = str;
              default = "root";
            };

            mode = mkOption {
              description = "Access mode of the secret";
              type = str;
              default = "0400";
            };
          };
        });
        default = { };
      };

      all = mkOption {
        description = ''
          List of all secrets available for this machine,
          including those aliased with `@machine`.
        '';
        type = listOf str;
        readOnly = true;
        default = if !cfg.enable then [ ] else
        pipe storageFile [
          builtins.readFile
          builtins.fromJSON
          (filterAttrs (_: x: builtins.hasAttr cfg.pub x.rcp))
          builtins.attrNames
          (x: pipe x [
            (builtins.filter (hasPrefix "${machineDst}/"))
            (map (y: "${machineLnk}${removePrefix machineDst y}"))
            (y: x ++ y)
          ])
        ];
      };
    };
  };

  config = mkIf cfg.enable {

    ##### management #####

    environment.systemPackages = [ sillysecrets ];

    ##### decryption & access control #####

    boot.initrd.systemd.mounts = [{
      before = [ "initrd-fs.target" ];
      requiredBy = [ "initrd-fs.target" ];

      type = "ramfs";
      what = "ramfs";
      where = "/sysroot${decryptDirMnt}";
    }];

    systemd = {
      services = {
        secrets-decrypt = {
          before = [ "sysinit-reactivation.target" "userborn.service" ];
          wantedBy = [ "sysinit-reactivation.target" "userborn.service" ];

          unitConfig.DefaultDependencies = false;

          serviceConfig = {
            Type = "oneshot";
            ExecStart = getExe (pkgs.writeShellApplication {
              name = "secrets-decrypt";
              runtimeInputs = with pkgs; [ diffutils sillysecrets ];
              text = ''
                ##### migrate old keys #####

                new="${cfg.key}"
                for i in /etc/aqs.key /etc/machine.key; do
                  old="${config.aquaris.persist.root}/$i"
                  echo "aquaris: migrate-old-keys: checking $old..."
                  [ ! -e "$old" ] && continue

                  if [ ! -e "$new" ]; then
                    cp -v "$old" "$new"
                  fi

                  if diff "$old" "$new" >/dev/null; then
                    rm -v "$old"
                  fi
                done

                ##### main #####

                rm -rvf "${decryptDirOut}"

                sesi --debug -k "${cfg.key}" \
                  -j "${storageFile}" -y "${structureFile}" \
                  dump "${decryptDirOut}"

                # create the machine alias
                if [ -e "${decryptDirOut}/${machineDst}" ]; then
                  ln -sfvT "${machineDst}" "${decryptDirOut}/${machineLnk}"
                fi

                # activate current decryption directory
                ln -sfvT "${decryptDirOut}" "${decryptDirTop}"

                # remove old decryption directories
                find "${decryptDirMnt}"         \
                  -mindepth 1 -maxdepth 1       \
                  -not -path "${decryptDirOut}" \
                  -exec rm -rfv {} \;
              '';
            });
          };
        };

        secrets-access-extra = {
          after = [ "secrets-decrypt.service" "userborn.service" ];
          wants = [ "secrets-decrypt.service" "userborn.service" ];

          wantedBy = [ "sysinit.target" ];

          unitConfig.DefaultDependencies = false;

          serviceConfig = {
            Type = "oneshot";
            ExecStart = getExe (pkgs.writeShellApplication {
              name = "secrets-access-extra";
              text = ''
                cd "${decryptDirTop}"

                # chown user secrets
                find . -type f -path './user/*' \
                | while read -r i; do
                  user="$(grep -oP '^\./user/\K[^/]+' <<< "$i")"
                  if [ "$i" != "./user/$user/password" ]; then
                    chown -v "''${user}:root" "$i"
                  fi
                done

                # load custom access rules
                systemd-tmpfiles --create ${ruleCfg}
              '';
            });
          };
        };
      };
    };

    ##### default usage #####

    security.pam.u2f.settings = {
      authfile = config.aquaris.secret' "user/%u/u2f-keys";
      expand = true;
    };

    users.users = (flip builtins.mapAttrs config.aquaris.users) (name: _: {
      hashedPasswordFile = config.aquaris.secret "user/${name}/password";
    });
  };
}
