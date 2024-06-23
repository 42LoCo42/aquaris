{ self, aquaris, pkgs, config, lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) package;
in
{
  options.aquaris.installer = mkOption {
    description = ''
      Installation script for this configuration.
      It uses nom and the configured binary caches.
    '';
    type = package;
    default = pkgs.writeShellApplication {
      name = "${aquaris.name}-installer";

      runtimeInputs = with pkgs; [
        nix-output-monitor
        nixos-install-tools
      ];

      text = aquaris.lib.subsT ./installer.sh {
        inherit self;
        inherit (aquaris) name;
        keys = config.nix.settings.trusted-public-keys;
        subs = config.nix.settings.trusted-substituters;
      };
    };
  };
}
