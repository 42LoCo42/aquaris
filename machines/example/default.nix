{ aquaris, ... }: {
  aquaris = {
    users = aquaris.lib.merge [
      { inherit (aquaris.cfg.users) dev; }
      { dev.admin = true; }
    ];

    machine = {
      id = "972c7b4d10cdec204831b039667be110";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAe61mAVmVqVWc+ZGoJnWDhMMpVXGwVFxeYH+QI0XSoo";
      secretKey = "/persist/aqs.key";
    };

    filesystems = { fs, ... }: {
      zpools.rpool.datasets = {
        "nixos/nix" = { };
        "nixos/persist" = { };
        "nixos/home/dev" = { };
      };

      disks."/dev/disk/by-id/virtio-root" = {
        partitions = [
          {
            type = "uefi";
            size = "512M";
            content = fs.regular {
              type = "vfat";
              mountpoint = "/boot";
            };
          }
          { size = "2G"; content = fs.swap; }
          { content = fs.zpool (p: p.rpool); }
        ];
      };
    };
  };

  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };

    "/var/log" = {
      device = "/persist/var/log";
      options = [ "bind" ];
    };
  };

  boot.initrd.systemd.emergencyAccess = true;
}
