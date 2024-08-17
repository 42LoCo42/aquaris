{
  inputs = {
    aquaris.url = "github:42loco42/aquaris/rewrite";
    aquaris.inputs.home-manager.follows = "home-manager";
    aquaris.inputs.nixpkgs.follows = "nixpkgs";
    aquaris.inputs.obscura.follows = "obscura";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    obscura.url = "github:42loco42/obscura";
  };

  outputs = { aquaris, self, ... }: aquaris self {
    # freeform global config, available as aquaris.cfg!

    users = {
      example = {
        description = "Example User";
        sshKeys = [ ]; # authorized to log in

        git = {
          email = "root@example.org";
          key = "";
        };
      };
    };
  };
}
