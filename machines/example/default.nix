{ pkgs, aquaris, ... }: {
  aquaris = {
    users = aquaris.lib.merge [
      { inherit (aquaris.cfg.users) dev; }
      { dev.admin = true; }
    ];

    machine = {
      id = "972c7b4d10cdec204831b039667be110";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAe61mAVmVqVWc+ZGoJnWDhMMpVXGwVFxeYH+QI0XSoo";
    };

    persist.enable = true;

    filesystems = { fs, ... }: {
      zpools.rpool = fs.defaultPool;

      disks."/dev/disk/by-id/virtio-root" = {
        partitions = [
          fs.defaultBoot
          {
            size = "2G";
            content = fs.btrfs {
              defaultVol.mountpoint = "/foo";
              subvols.bar.mountpoint = "/bar";
            };
          }
          {
            content = fs.luks {
              content = fs.zpool (p: p.rpool);
            };
          }
        ];
      };
    };
  };

  boot.initrd.systemd.emergencyAccess = true;

  services.zfs.autoSnapshot.enable = true;

  home-manager.users.dev = {
    aquaris = {
      emacs = {
        # enable = true;
        package = pkgs.emacs-gtk;
        config = ./emacs.org;
        extraPrograms = with pkgs; [
          gopls
          nil
        ];
      };

      persist = [
        "foo/bar/baz"
      ];
    };
  };
}
