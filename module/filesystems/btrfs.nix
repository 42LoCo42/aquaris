pkgs: { lib, config, ... }:
let
  inherit (lib) concatLines getExe ifEnable mapAttrs' mapAttrsToList mkOption pipe;
  inherit (lib.types) anything attrsOf functionTo listOf nullOr path str submodule;

  subvol = {
    mountpoint = mkOption {
      description = "Mount point of the subvolume";
      type = nullOr path;
      default = null;
    };

    mountOpts = mkOption {
      description = "Options for mount";
      type = listOf str;
      default = [ "defaults" ];
    };
  };
in
{
  options = {
    mkfsOpts = mkOption {
      description = "Options for mkfs.btrfs";
      type = listOf str;
      default = [ ];
    };

    mountOpts = mkOption {
      description = ''
        Default mount options for all subvolumes
        (including the default one)
      '';
      type = listOf str;
      default = [ "compress-force=zstd" ];
    };

    defaultVol = subvol;

    subvols = mkOption {
      description = "Subvolumes";
      type = attrsOf (submodule { options = subvol; });
      default = { };
    };

    _create = mkOption {
      type = functionTo str;
      readOnly = true;
      default = device: pipe config.subvols [
        (mapAttrsToList (name: _: ''btrfs subvolume create "$d/${name}"''))
        concatLines
        (x: pkgs.writeShellApplication {
          name = "btrfs-subvols";
          text = ''
            set -x
            d="$(mktemp -d)"
            mount -t btrfs "$1" "$d"
            ${x}
          '';
        })
        (x: ''
          mkfs.btrfs --verbose \
            ${builtins.concatStringsSep " " config.mkfsOpts} \
            ${device}

          unshare -m ${getExe x} ${device}
        '')
      ];
    };

    _mounts = mkOption {
      type = functionTo anything;
      readOnly = true;
      default = device: pipe config.subvols [
        (mapAttrs' (name: cfg: {
          name = cfg.mountpoint;
          value = {
            inherit device;
            fsType = "btrfs";
            options = config.mountOpts ++ cfg.mountOpts ++ [ "subvol=${name}" ];
          };
        }))
        (x: {
          fileSystems = x // ifEnable (config.defaultVol.mountpoint != null) {
            ${config.defaultVol.mountpoint} = {
              inherit device;
              fsType = "btrfs";
              options = config.mountOpts ++ config.defaultVol.mountOpts;
            };
          };
        })
      ];
    };
  };
}
