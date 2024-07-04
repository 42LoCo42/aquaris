{ pkgs, ... }:
let
  mkCommand = name: pkgs.writeShellApplication {
    inherit name;
    text = builtins.readFile ./${name}.sh;
  };
in
{
  environment.systemPackages = [
    (mkCommand "use")
    (mkCommand "_usepkgs")
  ];
}
