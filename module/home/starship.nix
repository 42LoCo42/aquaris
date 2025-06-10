{ config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.starship;
in
{
  options.aquaris.starship = mkEnableOption "the starship shell prompt";

  config = mkIf cfg {
    programs.starship = {
      enable = true;
      settings = {
        custom.usepkgs = {
          command = ''echo "[m[1m$USE_SHELL_PKGS[m"'';
          when = ''[ -n "$USE_SHELL_PKGS" ]'';
        };
        character = {
          success_symbol = "[λ](bold green)";
          error_symbol = "[λ](bold red)";
        };
      };
    };
  };
}
