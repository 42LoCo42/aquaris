{
  inputs = {
    aquaris = {
      url = "github:42loco42/aquaris";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
        obscura.follows = "obscura";
      };
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    obscura.url = "github:42loco42/obscura";
  };

  outputs = { aquaris, self, ... }: aquaris self {
    users = {
      alice = {
        sshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdkJo7RMoxUkuQ55YT1q5KANHrR+OJZzeYejpJW4rty"
        ];

        git = {
          email = "alice@example.org";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdkJo7RMoxUkuQ55YT1q5KANHrR+OJZzeYejpJW4rty";
        };
      };
    };
  };
}
