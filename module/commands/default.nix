{ pkgs, aquaris, ... }:
let
  use = pkgs.writeShellApplication {
    name = "use";
    text = builtins.readFile ./use.sh;
  };

  _usepkgs = pkgs.writeShellApplication {
    name = "_usepkgs";
    text = builtins.readFile ./_usepkgs.sh;
  };

  sys = pkgs.writeShellApplication {
    name = "sys";
    runtimeInputs = with pkgs; [
      nix-output-monitor
      nvd
    ];
    text = aquaris.lib.subsT ./sys.sh {
      inherit (aquaris) name;
    };
  };
in
{
  environment.systemPackages = [ sys use _usepkgs ];
}
