{ self, aquaris, pkgs, config, lib, ... }:
let
  inherit (lib) getExe mkOption;
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
      inherit (aquaris) name;

      runtimeInputs = with pkgs; [ nix-output-monitor ];

      text = aquaris.lib.subsT ./installer.sh {
        inherit self;
        inherit (aquaris) name;

        format = getExe config.aquaris.filesystems._create;
        mount = getExe config.aquaris.filesystems._mount;

        keys = config.nix.settings.trusted-public-keys;
        subs = config.nix.settings.trusted-substituters;
      };
    };
  };
}
