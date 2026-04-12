{ aquaris, lib, ... }: {
  aquaris = {
    users = lib.mkMerge [
      { inherit (aquaris.cfg.users) alice; }
      { alice.admin = true; }
    ];

    # generate via dbus-uuidgen
    machine.id = "98754c9fa9a46bdbc5b69bdd67503d1f";

    # generate via sesi keygen keys/<machineName>.key
    secrets.pub = "nvebU7_nZJL-LZsV_rzNwPNpsoIKdJv_RzhZCuWtn14";

    persist = {
      enable = true;

      dirs = {
        "/var/lib/example" = { };
      };
    };

    filesystems = { fs, ... }: {
      zpools.rpool = fs.defaultPool;

      disks."/dev/disk/by-id/virtio-root".partitions = [
        fs.defaultBoot
        {
          content = fs.luks {
            content = fs.zpool (p: p.rpool);

            tpmDecrypt = true;
            tpmMeasure = true;
          };
        }
      ];
    };

    dnscrypt.enable = true;
  };

  home-manager.sharedModules = [{
    aquaris = {
      firefox = {
        enable = false;

        sanitize = {
          enable = true;
          exceptions = [
            "https://example.org"
            "https://github.com"
          ];
        };
      };

      persist = {
        ".cache/nix" = { e = false; };
        "foo bar/baz qux" = { m = "0700"; };
      };
    };
  }];
}
