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
          command = "_usepkgs";
          when = ''[ -n "$IN_USE_SHELL" ]'';
        };
        character = {
          success_symbol = "[λ](bold green)";
          error_symbol = "[λ](bold red)";
        };
      };
    };
  };
}
