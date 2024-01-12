{
  aquaris = {
    filesystem = { filesystem, zpool, ... }: {
      zpools.rpool.datasets = {
        # "nixos" = {
        #   datasets = {
        #     "nix" = { };
        #     "persist" = { };
        #     "home" = {
        #       "leonsch" = { };
        #       "guy" = { };
        #     };
        #   };
        # };
      };

      disks = {
        "root".partitions = [
          {
            type = "uefi";
            size = "512M";
            content = filesystem {
              type = "vfat";
              mountpoint = "/boot";
            };
          }
          {
            type = "linux";
            size = null;
            content = zpool (p: p.rpool);
          }
        ];
      };
    };

    persist = {
      users.leonsch = [
        ".cache/zsh"
      ];
    };
  };
}
