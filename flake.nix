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
        # (agenix self) # TODO
        (lanza system)
        (nix-settings self)
        (sys-settings self)

        {
          aquaris.sys-settings.machineID = "92f3ebbc37482e645a111e286584a616";
          fileSystems."/".device = "placeholder";
        }
      ];
    };
  };
}
