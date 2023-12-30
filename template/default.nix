let
  users = {
    example = {
      name = "foobar"; # optional override
      publicKey = ""; # ssh-keygen -t ed25519 -f ...
    };
  };

  machines = {
    example = {
      id = ""; # dbus-uuidgen
      publicKey = ""; # ssh-keygen -t ed25519 -f ...
      admins = { inherit (users) foo; }; # replace with actual user
      users = { inherit (users) foo; }; # don't add the same user to both sets!
    };
  };
in
{ inherit users machines; }
