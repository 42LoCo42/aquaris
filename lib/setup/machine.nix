"$machine" = {
  # system = "aarch64-linux" # override nixpkgs system
  id = "$id";
  publicKey = "$pub";
  extraKeys = [ ];
  admins = { inherit (users) $admins; };
  users = { inherit (users) $users; };
};
