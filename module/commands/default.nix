{ pkgs, lib, config, aquaris, ... }:
let
  inherit (lib) mkIf mkMerge;
  inherit (config.aquaris.machine) keepGenerations;

  sys = pkgs.writeShellApplication {
    name = "sys";

    runtimeInputs = with pkgs; [
      diffutils
      dix
      jq
      nix-output-monitor
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

  eph = pkgs.writers.writePython3Bin "_eph" { doCheck = false; } ./eph.py;
in
mkMerge [
  { environment.systemPackages = [ sys use ]; }

  (mkIf config.aquaris.persist.enable {
    environment = {
      systemPackages = [ eph ];

      shellAliases = {
        "eph" = "sudo _eph | less";
      };
    };
  })
]
