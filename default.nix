let
  users = {
    leonsch = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVieLCkWGImVI9c7D0Z0qRxBAKf0eaQWUfMn0uyM/Ql";
      git = {
        name = "Leon Schumacher";
        email = "leonsch@protonmail";
        key = "C743EE077172986F860FC0FE2F6FE1420970404C";
      };
    };

    guy = {
      name = "justaguy"; # override actual user name
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF7FppRoKRh+rTSnxFHodYmZ6lVEa4UWN7c0Sgy+trgl";
      git = {
        name = "J. A. Guy";
        email = "guy@example.org";
        # key is optional
      };
    };
  };

  machines = {
    castor = {
      id = "10ec6fa7b2fdeea772a40b31658fead8";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH8ebcoYSzs9koGhq9KtIqwgcJYj0siYdYv6hVUT/S/G";
      admins = { inherit (users) leonsch; }; # admins get sudo permissions & encryption access to machine secrets
      users = { inherit (users) guy; };
    };

    pollux = {
      # system = "aarch64-linux"; # optional, x86_64-linux is default
      id = "e755aeadc6c3f08afd03cf71658c2190";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGosXDmm4fVV28nlworyjrUxNLzqMVDqbkXGipM7ls+B";
      admins = { inherit (users) guy; };
    };
  };
in
{ inherit users machines; }
