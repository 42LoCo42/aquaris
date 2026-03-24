{ aquaris, config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.direnv;
in
{
  options.aquaris.direnv = mkEnableOption "direnv and nix-direnv integration";

  imports = [
    aquaris.inputs.obscura.homeModules.direnv-instant
  ];

  config = mkIf cfg {
    programs = {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
        stdlib = builtins.readFile ./cache.sh;
      };

      direnv-instant = {
        enable = true;

        settings = {
          mux_delay = 0;
        };
      };
    };
  };
}
