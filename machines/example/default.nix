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

    # persist.enable = true;

    filesystems = { fs, ... }: {
      # zpools.rpool = fs.defaultPool;

      lvm.nixos.volumes = {
        root = {
          size = "10G";
          content = fs.regular {
            type = "ext4";
            mountpoint = "/";
          };
        };

        var = {
          size = "10G";
          content = fs.regular {
            type = "ext4";
            mountpoint = "/var";
          };
        };

        home.content = fs.regular {
          type = "ext4";
          mountpoint = "/home";
        };
      };

      disks."/dev/disk/by-id/virtio-root" = {
        partitions = [
          fs.defaultBoot
          fs.ignore
          {
            content = fs.luks {
              content = fs.lvm (x: x.nixos);
            };
          }

          # {
          #   size = "2G";
          #   content = fs.btrfs {
          #     defaultVol.mountpoint = "/foo";
          #     subvols.bar.mountpoint = "/bar";
          #   };
          # }
          # {
          #   content = fs.luks {
          #     keyFile = pkgs.writeText "key" "password";
          #     content = fs.zpool (p: p.rpool);
          #   };
          # }
        ];
      };
    };
  };

  boot.initrd.systemd.emergencyAccess = true;

  services.zfs.autoSnapshot.enable = true;

  home-manager.users.dev = {
    aquaris.persist = [
      "foo/bar/baz"
    ];
  };
}
