# don't forget to generate hardware.nix!
# nixos-generate-config --show-hardware-config --no-filesystems

{ aquaris, ... }: {
  aquaris = {
    users = aquaris.lib.merge [
      { inherit (aquaris.cfg.users) example; }
      { example.admin = true; }
    ];

    machine = {
      id = ""; # dbus-uuidgen
      key = ""; # ssh-keygen -qN "" -t ed25519 -f keys/example.key; cat keys/example.key.pub
    };

    # persist.enable = true; # enables root-on-tmpfs and persistence options

    filesystems = { fs, ... }: {
      disks."/dev/disk/by-id/foobar".partitions = [
        fs.defaultBoot # 512M ESP at /boot

        { size = "4G"; content = fs.swap; }

        # last partition doesn't need size; fills remaining space

        # regular filesystem
        {
          content = fs.regular {
            type = "ext4";
            mountpoint = "/";
          };
        }

        # BTRFS with subvolumes
        {
          content = fs.btrfs {
            mountpoint = "/btrfs";
            subvols = {
              root.mountpoint = "/";
              home.mountpoint = "/home";
            };
          };
        }

        # encrypted partition
        {
          content = fs.luks {
            content = null;
          };
        }

        # zpool member
        { content = fs.zpool (p: p.rpool); }
      ];

      zpools.rpool = fs.defaultPool; # rpool/nixos/{nix, home/<user>}
    };
  };
}
