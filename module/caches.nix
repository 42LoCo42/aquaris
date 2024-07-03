{ config, lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) listOf str submodule;
  cfg = config.aquaris.caches;
in
{
  options.aquaris.caches = mkOption {
    description = "Set of binary caches";
    type = listOf (submodule {
      options = {
        url = mkOption {
          description = "URL of the binary cache";
          type = str;
        };

        key = mkOption {
          description = "Public key of the binary cache";
          type = str;
        };
      };
    });
  };

  config = {
    aquaris.caches = [
      {
        # for lanzaboote
        url = "https://nix-community.cachix.org";
        key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      }
      {
        # my personal cache
        url = "https://attic.eleonora.gay/default";
        key = "default:3FYh8sZV8gWa7Jc5jlP7gZFK7pt3kaHRiV70ySaQ42g=";
      }
    ];

    nix.settings = {
      substituters = map (x: x.url) cfg;
      trusted-public-keys = map (x: x.key) cfg;
    };
  };
}
