{ config, lib, disko, ... }:
let
  inherit (lib) mapAttrs' mkOption types;
  inherit (types) str;
  cfg = config.aquaris.filesystem;
  persist = config.aquaris.persistence.root;
in
{
  options.aquaris.filesystem = {
    rootDisk = mkOption {
      type = str;
      description = "ID of the root disk (from /dev/disk/by-id)";
    };
  };

  imports = [ disko.nixosModules.default ];

  config = {
    disko.devices = {
      disk.root = {
        type = "disk";
        device = "/dev/disk/by-id/${cfg.rootDisk}";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };

      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = [ "mode=755" ];
      };

      zpool.rpool = {
        options = {
          ashift = "12";
          autoexpand = "on";
          autoreplace = "on";
          autotrim = "on";
          listsnapshots = "on";
        };

        rootFsOptions = {
          acltype = "posix";
          compression = "zstd";
          dnodesize = "auto";
          mountpoint = "none";
          normalization = "formD";
          relatime = "on";
          xattr = "sa";
        };

        datasets = {
          "nixos" = {
            type = "zfs_fs";
          };

          "nixos/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };

          "nixos/persist" = {
            type = "zfs_fs";
            mountpoint = persist;
          };

          "nixos/home" = {
            type = "zfs_fs";
          };
        } // (mapAttrs'
          (name: _: {
            name = "nixos/home/${name}";
            value = {
              type = "zfs_fs";
              mountpoint = "${persist}/home/${name}";
            };
          })
          config.aquaris.users);
      };
    };
  };
}
