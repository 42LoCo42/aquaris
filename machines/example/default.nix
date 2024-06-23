{ aquaris, ... }: {
  aquaris = {
    users = {
      alice = aquaris.cfg.users.alice // { admin = true; };
      inherit (aquaris.cfg.users) bob;
    };

    machine = {
      id = "c4e83977cfaf1b126d3af79d667802d2";
    };
  };
}
