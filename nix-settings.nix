src: { config, lib, ... }:
let
  inherit (lib) mkForce mkIf mkMerge mkOption pipe types;
  inherit (types) bool listOf str;
  cfg = config.aquaris.nix-settings;
in
{
  options.aquaris.nix-settings = {
    linkChannel = mkOption {
      type = bool;
      default = true;
    };

    linkInputs = mkOption {
      type = listOf str;
      default = builtins.attrNames src.inputs;
    };
  };

  config = mkMerge [
    {
      nix = {
        settings = {
          auto-optimise-store = true;
          experimental-features = [ "nix-command" "flakes" ];
          substituters = [
            "https://42loco42.cachix.org"
          ];
          trusted-public-keys = [
            "42loco42.cachix.org-1:6HvWFER3RdTSqEZDznqahkqaoI6QCOiX2gRpMMsThiQ="
          ];
        };

        extraOptions = ''
          keep-outputs = true
          keep-derivations = true
        '';

        registry =
          let
            lock = pipe "${src}/flake.lock" [
              builtins.readFile
              builtins.fromJSON
            ];
            inherit (lock) nodes;
            inputs = nodes.${lock.root}.inputs;
          in
          pipe cfg.linkInputs [
            (map (name: {
              inherit name;
              value.to = nodes.${inputs.${name}}.locked;
            }))
            builtins.listToAttrs
          ];
      };
    }

    (mkIf cfg.linkChannel {
      environment.etc."nix/channel".source = src.inputs.nixpkgs.outPath;
      nix.nixPath = mkForce [ "nixpkgs=/etc/nix/channel" ];
    })
  ];
}
