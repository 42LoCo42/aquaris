{ pkgs, config, aquaris, ... }:
let
  inherit (config.aquaris.machine) keepGenerations;

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
      keepGenerations = if keepGenerations == null then "" else ''
        sudo nix-env \
          --profile /nix/var/nix/profiles/system \
          --delete-generations "+${toString keepGenerations}"
      '';
    };
  };
in
{ environment.systemPackages = [ sys use _usepkgs ]; }
