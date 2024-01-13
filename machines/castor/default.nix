{ config, lib, ... }: {
  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  aquaris = {
    filesystem = { filesystem, zpool, ... }: {
      zpools.rpool.datasets = {
        "nixos/nix" = { };
      } // (lib.mapAttrs'
        (_: user: {
          name = "nixos/persist/home/${user.name}";
          value = { };
        })
        config.aquaris.users);

      disks = {
        "/dev/loop0" = {
          partSep = "p";
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
