{ ... }: {
  aquaris = {
    users = {
      bob = { admin = true; };
    };

    machine = {
      id = "f305f56f4390b9636ee704eb66787b13";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMxDER3OTMav9oi9nhEGJWx1FI2XSyDMDDOaptxDKPAV";
    };
  };

  # TODO remove when relevant modules are done
  users.users.bob.password = " ";
  fileSystems."/".device = "none";
}
