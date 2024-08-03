{ config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.direnv;
in
{
  options.aquaris.direnv = mkEnableOption "direnv and nix-direnv integration";

  config = mkIf cfg {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
