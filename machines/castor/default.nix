{
  aquaris = {
    filesystem.rootDisk = "/dev/disk/by-id/virtio-root";

    persist = {
      users.leonsch = [
        ".cache/zsh"
      ];
    };
  };
}
