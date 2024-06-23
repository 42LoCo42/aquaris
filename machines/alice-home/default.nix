{ ... }: {
  aquaris = {
    users = {
      alice = { admin = true; };
      bob = { };
    };

    machine = {
      id = "c4e83977cfaf1b126d3af79d667802d2";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2MQ07cjL8Yog44q0Qq1NUNlW3eEHS3Pr4+84TFaTHE";
    };
  };

  # TODO remove when relevant modules are done
  users.users.alice.password = " ";
  fileSystems."/".device = "none";
}
