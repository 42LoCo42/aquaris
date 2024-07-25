{ pkgs, lib, mkEnableOption, config, osConfig, ... }: {
  options.aquaris.misc = mkEnableOption "miscellaneous packages and settings";

  config = {
    home = {
      packages = with pkgs; [
        file
        jq
        lsof
        man-pages
        man-pages-posix
        nil
        nix-output-monitor
        nixpkgs-fmt
        pciutils
        shellcheck
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

      sessionVariables.NIXOS_CONFIG_DIR = lib.mkDefault
        "${osConfig.aquaris.persist.root}/${config.home.homeDirectory}/config";
    };

    programs = {
      fzf.enable = true;
      ripgrep.enable = true;
      zoxide.enable = true;
    };
  };
}
