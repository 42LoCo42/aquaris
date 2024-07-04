{ pkgs, ... }: {
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
  };

  programs = {
    fzf.enable = true;
    ripgrep.enable = true;
    zoxide.enable = true;
  };
}
