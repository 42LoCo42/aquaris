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
  };

  services.zfs.autoSnapshot.enable = true;
}
