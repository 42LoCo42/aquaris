{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "";
  };

  outputs = { self, nixpkgs, ... }@specialArgs: rec {
    nixosModules = {
      agenix = import ./agenix.nix;
      lanza = import ./lanza.nix;
      nix-settings = import ./nix-settings.nix;
      sys-settings = import ./sys-settings.nix;
    };

    nixosConfigurations.test = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      inherit specialArgs;

      modules = with nixosModules; [
        (agenix self)
        (lanza system)
        (nix-settings self)
        (sys-settings self)

        {
          fileSystems."/".device = "/dev/sda1";
        }
      ];
    };
  };
}
