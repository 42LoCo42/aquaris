{ pkgs, ... }: {
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
}