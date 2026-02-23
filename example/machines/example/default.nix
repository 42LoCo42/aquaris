{ aquaris, ... }: {
  aquaris = {
    users = aquaris.lib.merge [
      { inherit (aquaris.cfg.users) alice; }
      { alice.admin = true; }
    ];

    # generate via dbus-uuidgen
    machine.id = "98754c9fa9a46bdbc5b69bdd67503d1f";

    persist.enable = true;

    filesystems = { fs, ... }: {
      zpools.rpool = fs.defaultPool;

      disks."/dev/disk/by-id/virtio-root".partitions = [
        fs.defaultBoot
        { content = fs.zpool (p: p.rpool); }
      ];
    };

    dnscrypt.enable = true;

    secrets.rules = {
      "@machine/something" = {
        user = "alice";
        group = "wheel";
        mode = "0444";
      };
    };

    persist.dirs."/abc def/ghi jkl" = { };
  };

  boot.kernelParams = [ "foo=bar" ];

  home-manager.sharedModules = [{
    aquaris = {
      firefox = {
        enable = true;

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
