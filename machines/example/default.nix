{ pkgs, aquaris, ... }: {
  aquaris = {
    users = aquaris.lib.merge [
      { inherit (aquaris.cfg.users) dev; }
      {
        dev = {
          admin = true;
          persist = [ "foo/bar/baz" ];
        };
      }
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

    # TODO: move into module/home
    emacs = {
      enable = true;
      package = pkgs.emacs-gtk;
      config = ./emacs.org;
      extraPrograms = with pkgs; [
        gopls
        nil
      ];
    };
  };

  boot.initrd.systemd.emergencyAccess = true;
}
