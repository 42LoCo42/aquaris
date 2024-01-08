{
  aquaris = {
    filesystem.rootDisk = "virtio-root";

    persistence = {
      users.leonsch = [
        ".cache/zsh"
      ];
    };
  };
}
