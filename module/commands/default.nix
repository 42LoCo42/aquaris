{ pkgs, config, aquaris, ... }:
let
  inherit (config.aquaris.machine) keepGenerations;

  sys = pkgs.writeShellApplication {
    name = "sys";

    runtimeInputs = with pkgs; [
      diffutils
      jq
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

  use = pkgs.writeShellApplication {
    name = "use";
    text = builtins.readFile ./use.sh;

    runtimeInputs = with pkgs; [
      jq
      nix-output-monitor
      parallel
    ];
  };
in
{ environment.systemPackages = [ sys use ]; }
