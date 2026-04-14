{ aquaris, self, pkgs, lib, config, ... }:
let
  inherit (lib)
    attrNames
    concatLines
    elem
    elemAt
    filter
    filterAttrs
    flip
    fromJSON
    getExe
    hasAttr
    hasPrefix
    hashString
    mapAttrs
    mapAttrsToList
    mkIf
    mkOption
    pipe
    readFile
    removePrefix
    splitString
    versionAtLeast
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

  inherit (self.inputs.obscura.packages.${pkgs.stdenv.system}) sillysecrets;

  cfg = config.aquaris.secrets;

  secretsFile = builtins.path { path = "${self.cfgDir}/sillysecrets.yaml"; };

  structure = pipe secretsFile [
    (x: (pkgs.runCommandLocal "structure" {
      nativeBuildInputs = with pkgs; [ yq ];
    }) "yq -s '.[0]' < ${x} > $out")
    readFile
    fromJSON
  ];

  storageRaw = pipe secretsFile [
    readFile
    (splitString "\n\n--- # Don't touch!\n\n")
    (flip elemAt 1)
  ];

  storage = fromJSON storageRaw;

  decryptDirTop = cfg.directory;
  decryptDirMnt = "${dirOf decryptDirTop}/.${baseNameOf decryptDirTop}.d";
  decryptDirOut = "${decryptDirMnt}/${hashString "sha256" storageRaw}";

  machineDst = "machine/${aquaris.name}";
  machineLnk = "@machine";

  accessor = checked: mkOption {
    type = functionTo path;
    readOnly = true;
    default = if !cfg.enable then _: "/dev/null" else
    name:
    if checked && !(elem name cfg.all)
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
        pipe storage [
          (filterAttrs (_: x: hasAttr cfg.pub x.rcp))
          attrNames
          (x: pipe x [
            (filter (hasPrefix "${machineDst}/"))
            (map (y: "${machineLnk}${removePrefix machineDst y}"))
            (y: x ++ y)
          ])
        ];
      };
    };
  };

  config = mkIf cfg.enable {

    ##### management #####

    assertions = [{
      assertion = versionAtLeast sillysecrets.version "2.2.0";
      message = "sillysecrets version needs to be >= 2.2.0 for combined secrets file support!";
    }];

    environment.systemPackages = [ sillysecrets ];

    ##### decryption & access control #####

    boot.initrd.systemd.mounts = [{
      before = [ "initrd-fs.target" ];
      requiredBy = [ "initrd-fs.target" ];

      type = "ramfs";
      what = "ramfs";
      where = "/sysroot${decryptDirMnt}";
      options = "nosuid";
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

                sesi                      \
                  --debug                 \
                  --key  "${cfg.key}"     \
                  --file "${secretsFile}" \
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

    users.users = pipe config.aquaris.users [
      (filterAttrs (n: _: n != "root"))
      (mapAttrs (n: _: {
        hashedPasswordFile = config.aquaris.secret "user/${n}/password";
      }))
    ];
  };
}
