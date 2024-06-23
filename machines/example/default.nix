{ aquaris, ... }: {
  aquaris = {
    users = {
      alice = aquaris.users.alice // { admin = true; };
      inherit (aquaris.users) bob;
    };
  };

  _module.args.foo = aquaris;
}
