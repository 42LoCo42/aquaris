let
  users = {
    leonsch = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVieLCkWGImVI9c7D0Z0qRxBAKf0eaQWUfMn0uyM/Ql";
    };

    guy = {
      name = "justaguy"; # override actual user name
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9fBvv8AWOYsItzYlomBJ41lGHwhV0cNtlyADn0zdP4";
    };
  };

  machines = {
    castor = {
      id = "10ec6fa7b2fdeea772a40b31658fead8";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFR6KcY2CciSPuye3+OC3rj44adWz/1ZvqGMwpG+tlf";
      admins = { inherit (users) leonsch; }; # admins get sudo permissions & encryption access to machine secrets
      users = { inherit (users) guy; };
    };

    pollux = {
      # system = "aarch64-linux"; # optional, x86_64-linux is default
      id = "e755aeadc6c3f08afd03cf71658c2190";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0GHFF8wVFr5CGLMxyUSf/t4B2vaRor1IGVlrOh8I8y";
      admins = { inherit (users) guy; };
    };
  };
in
{ inherit users machines; }
