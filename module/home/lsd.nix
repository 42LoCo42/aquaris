{ config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.lsd;
in
{
  options.aquaris.lsd = mkEnableOption "lsd, a better ls";

  config = mkIf cfg {
    programs.lsd = {
      enable = true;
      enableAliases = true;
      settings = {
        sorting.dir-grouping = "first";
      };
    };
  };
}
