{ pkgs, config, lib, aquaris, ... }:
let
  inherit (lib) ifEnable mkDefault mkOption pipe;
  inherit (lib.types) attrsOf listOf package submodule submoduleWith;

  fs = aquaris.lib.adt {
    regular = ./regular.nix;
    swap = ./swap.nix;
    zpool = ./zpoolMember.nix;
  };

  getEntries = f: v: pipe v [
    (v: if builtins.isAttrs v then builtins.attrValues v else v)
    (map f)
    (builtins.concatStringsSep "\n")
  ];

  util = {
    inherit (aquaris.lib) merge;
    inherit fs getEntries;
  };

  cfg = config.aquaris.filesystems;
in
{
  options.aquaris.filesystems = mkOption {
    description = "Declarative filesystem configuration";
    type = submoduleWith {
      specialArgs = {
        fs = fs.mk // {
          swap = fs.mk.swap { };
          zpool = f: fs.mk.zpool {
            pool = (f cfg.zpools).name;
          };
        };
      };

      modules = [{
        options = {
          disks = mkOption {
            type = attrsOf (submodule (import ./disk.nix util));
            default = { };
          };

          zpools = mkOption {
            type = attrsOf (submodule (import ./zpool.nix util));
            default = { };
          };

          tools = mkOption {
            description = "Packages available to the generated scripts";
            type = listOf package;
          };

          _create = mkOption {
            type = package;
            readOnly = true;
            default = pkgs.writeShellApplication {
              name = "${aquaris.name}-create";
              runtimeInputs = cfg.tools;
              text = ''
                set -x
                ${getEntries (x: x._create) cfg.disks}
                ${getEntries (x: x._create) cfg.zpools}
              '';
            };
          };

          _mount = mkOption {
            type = package;
            readOnly = true;
            default = pkgs.writeShellApplication {
              name = "${aquaris.name}-mount";
              runtimeInputs = cfg.tools;
              text = ''
                mnt="''${1-/mnt}"

                < ${config.environment.etc.fstab.source}  \
                  grep -v '^#' | grep .                   \
                | while read -r src dst type options _; do
                    if [ "$type" == "swap" ]; then
                      (set -x; swapon "$src")
                      continue
                    fi

                    if tr ',' '\n' <<< "$options" | grep -Eqx 'r?bind'; then
                      src="$mnt/$src"
                      (set -x; mkdir -p "$src")
                    fi

                    dst="$mnt/$dst"

                    # shellcheck disable=SC2001
                    options="$(sed "s|=/|=$mnt/|g" <<< "$options")"

                    (set -x; mount -m "$src" "$dst" -t "$type" -o "$options")
                done
              '';
            };
          };
        };
      }];
    };
    default = { };
  };

  config =
    let
      mounts = pipe cfg [
        (x: with x; [ disks zpools ])
        (map (x: pipe x [
          builtins.attrValues
          (map (x: x._mounts))
          util.merge
        ]))
        util.merge
      ];
    in
    {
      aquaris.filesystems.tools = with pkgs; [
        config.boot.zfs.package
        dosfstools
      ];

      fileSystems = mounts.fileSystems or { };
      swapDevices = mounts.swapDevices or [ ];

      boot = ifEnable (cfg.zpools != { }) {
        kernelPackages = mkDefault config.boot.zfs.package.latestCompatibleLinuxPackages;
        supportedFilesystems.zfs = mkDefault true;
      };
    };
}
