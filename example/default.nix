let
  users = {
    leonsch = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVieLCkWGImVI9c7D0Z0qRxBAKf0eaQWUfMn0uyM/Ql";
    };

    guy = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9fBvv8AWOYsItzYlomBJ41lGHwhV0cNtlyADn0zdP4";
    };
  };

  machines = {
    castor = {
      id = "10ec6fa7b2fdeea772a40b31658fead8";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFR6KcY2CciSPuye3+OC3rj44adWz/1ZvqGMwpG+tlf";
      admin = users.leonsch; # admin gets sudo permissions & encryption access to machine secrets
      users = { inherit (users) guy; }; # normal users don't
    };

    pollux = {
      id = "e755aeadc6c3f08afd03cf71658c2190";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0GHFF8wVFr5CGLMxyUSf/t4B2vaRor1IGVlrOh8I8y";
      admin = users.guy;
    };
  };
in
{ inherit users machines; }
