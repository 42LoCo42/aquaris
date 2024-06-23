{ nixpkgs, lib }: lib.eachDefaultSystem (system:
let pkgs = import nixpkgs { inherit system; }; in {
  packages.default = pkgs.writeShellApplication {
    name = "aqs";
    text = builtins.readFile ./aqs.sh;
    runtimeInputs = with pkgs; [
      age
      jq
      nix
    ];
  };
}
)
