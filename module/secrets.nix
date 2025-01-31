{ aquaris, self, pkgs, lib, config, ... }:
let
  inherit (lib)
    flip
    getExe
    mapAttrsToList
    mkIf
    mkOption
    ;
  inherit (lib.types)
    attrsOf
    bool
    functionTo
    path
    str
    submodule
    ;

  cfg = config.aquaris.secrets;

  secretsFile = builtins.path { path = "${self.cfgDir}/sesi.yaml"; };
  decryptDirTop = cfg.directory;
  decryptDirMnt = "${decryptDirTop}.d";
  decryptDirOut = "${decryptDirMnt}/${builtins.hashFile "sha256" secretsFile}";

  machine = "machine:${aquaris.name}";
  sillysecrets = aquaris.inputs.obscura.packages.${pkgs.system}.sillysecrets;

  name2path.__functor = mkOption {
    description = "Converts a secret name to its output path";
    type = functionTo (functionTo path);
    default = _: name: "${decryptDirTop}/${name}";
  };
in
{
  options.aquaris.secret = name2path;

  options.aquaris.secrets = name2path // {
    enable = mkOption {
      description = "Enable the secrets management module";
      type = bool;
      default = true;
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
      type = attrsOf (submodule ({
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
      }));
      default = { };
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

                sesi -f "${secretsFile}" -i "${cfg.key}" \
                  decryptall "${machine}" "${decryptDirOut}"

                # create the machine alias
                mv "${decryptDirOut}/${machine}" "${decryptDirOut}/machine"

                # activate current decryption directory
                ln -sfT "${decryptDirOut}" "${decryptDirTop}"

                # remove old decryption directories
                find "${decryptDirMnt}"         \
                  -mindepth 1 -maxdepth 1       \
                  -not -path "${decryptDirOut}" \
                  -exec rm -rfv {} \;

                # create all links
                find -L "${decryptDirTop}" -type f \
                | while read -r src; do
                  dst="''${src//://}"
                  if [ ! -e "$dst" ]; then
                    mkdir -p "$(dirname "$dst")"
                    ln -s "$src" "$dst"
                  fi
                done
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

                # make all directories visible
                find . -type d -exec chmod 755 {} \;

                # chown user secrets
                find . -type f -path './user:*' \
                | while read -r i; do
                  user="$(grep -oP '^\./user:\K[^/]+' <<< "$i")"
                  if [ "$i" = "./user:$user/password" ]; then
                    chown root:root "$i"
                  else
                    chown "''${user}:root" "$i"
                  fi
                done

                # load custom access rules
                systemd-tmpfiles --create
              '';
            });
          };
        };
      };

      tmpfiles.rules = (flip mapAttrsToList cfg.rules (name: cfg:
        "z ${decryptDirTop}/${name} ${cfg.mode} ${cfg.user} ${cfg.group}")) ++
      [ "z ${cfg.key} 0400 0 0" ];
    };

    ##### default usage #####

    security.pam.u2f.settings = {
      authfile = cfg "user/%u/u2f-keys";
      expand = true;
    };

    users.users = (flip builtins.mapAttrs config.aquaris.users) (name: _: {
      hashedPasswordFile = cfg "user/${name}/password";
    });
  };
}
