{ pkgs, lib, config, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.bat;
in
{
  options.aquaris.bat = mkEnableOption "bat for manpage rendering";

  config = mkIf cfg {
    home.sessionVariables = {
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      MANROFFOPT = "-c";
    };

    programs.bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [ batman ];
      config = {
        theme = "gruvbox-dark";
        pager = "less -fR";
      };
    };
  };
}
