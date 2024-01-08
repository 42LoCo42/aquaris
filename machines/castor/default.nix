{
  aquaris = {
    filesystem.rootDisk = "virtio-root";

    persist = {
      users.leonsch = [
        ".cache/zsh"
      ];
    };
  };
}
