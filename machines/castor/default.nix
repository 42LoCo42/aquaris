{
  aquaris = {
    filesystem = { filesystem, zpool, ... }: {
      zpools.rpool.datasets = {
        "nixos" = { };
        "nixos/nix" = { };
        "nixos/persist" = { };
        "nixos/persist/home".mountpoint = null;
        "nixos/persist/home/guy" = { };
        "nixos/persist/home/leonsch" = { };
      };

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
