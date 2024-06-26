{ aquaris, ... }: {
  aquaris = {
    users = {
      inherit (aquaris.cfg.users) dev;
    } // {
      dev.admin = true;
    };

    machine = {
      id = "972c7b4d10cdec204831b039667be110";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAe61mAVmVqVWc+ZGoJnWDhMMpVXGwVFxeYH+QI0XSoo";
    };
  };

  # TODO remove when relevant modules are done
  fileSystems."/".device = "none";
}
