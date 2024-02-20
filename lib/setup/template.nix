{
  inputs = {
    aquaris.url = "github:42loco42/aquaris";
    aquaris.inputs.home-manager.follows = "home-manager";
    aquaris.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, aquaris, ... }:
    let
      users = { $users };
      machines = { $machines };
    in
    aquaris.lib.main self { inherit users machines; };
}
