{ config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.neofetch;
in
{
  options.aquaris.neofetch = mkEnableOption "neofetch (but trans :3)";

  config = mkIf cfg {
    home.shellAliases.neofetch = "hyfetch";

    programs = {
      fastfetch.enable = true;

      hyfetch = {
        enable = true;
        settings = {
          backend = "fastfetch";
          pride_month_disable = false;

          mode = "rgb";
          light_dark = "dark";
          lightness = 0.5;

          preset = "transgender";
          color_align = {
            mode = "custom";
            custom_colors = {
              "1" = 1;
              "2" = 0;
            };
          };
        };
      };
    };
  };
}
