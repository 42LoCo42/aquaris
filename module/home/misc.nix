{ pkgs, lib, mkEnableOption, config, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.misc;
in
{
  options.aquaris.misc = mkEnableOption "miscellaneous packages and settings";

  config = mkIf cfg {
    aquaris.persist = { "config" = { }; };

    home = {
      packages = with pkgs; [
        file
        lsof
        man-pages
        man-pages-posix
        pciutils
        tree
      ];

      shellAliases = {
        cd = "z";
        ip = "ip -c";
        mkdir = "mkdir -pv";
        rmdir = "rmdir -pv";
        switch = "sys rebuild";
        yay = "sys update build switch";
      };

      sessionVariables = {
        GOPATH = "$HOME/.local/share/go";
        NIXOS_CONFIG_DIR = lib.mkDefault ''$(realpath "$HOME/config")'';
      };
    };

    programs = {
      ripgrep.enable = true;
      zoxide.enable = true;
    };

    xdg.enable = true;
  };
}
