{ config, lib, ... }: {
  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  aquaris = {
    filesystem = { filesystem, zpool, ... }: {
      zpools.rpool.datasets = {
        "nixos/nix" = { };
      } //
      # TODO find a better place for this
      # this is a default thing and should not be part of
      # the machine-specific configuration
      (lib.mapAttrs'
        (_: user: {
          name = "nixos${config.aquaris.persist.root}/home/${user.name}";
          value = { };
        })
        config.aquaris.users);

      disks = {
        "/dev/disk/by-id/virtio-root" = {
          partitions = [
            {
              type = "uefi";
              size = "512M";
              content = filesystem {
                type = "vfat";
                mountpoint = "/boot";
              };
            }
            { content = zpool (p: p.rpool); }
          ];
        };
      };
    };

    persist = {
      users.leonsch = [
        ".cache/zsh"
      ];
    };
  };
}
