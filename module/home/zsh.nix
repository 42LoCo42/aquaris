{ pkgs, config, ... }:
let cache = "$HOME/.cache/zsh"; in {
  home.file.".profile".text = ''
    source "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    autocd = true;
    defaultKeymap = "emacs";
    history.path = "${cache}/history";

    initExtra = ''
      # bindkey "" insert-cycledright
      # bindkey "" insert-cycledleft

      bindkey "[1;3C" forward-word
      bindkey "[1;3D" backward-word

      # https://github.com/zsh-users/zsh-syntax-highlighting/issues/295#issuecomment-214581607
      zstyle ':bracketed-paste-magic' active-widgets '.self-*'
    '';

    plugins = [
      rec {
        name = "zsh-fzf-history-search";
        src = pkgs.fetchFromGitHub {
          owner = "joshskidmore";
          repo = name;
          rev = "d1aae98";
          hash = "sha256-4Dp2ehZLO83NhdBOKV0BhYFIvieaZPqiZZZtxsXWRaQ=";
        };
      }
    ];

    oh-my-zsh = {
      enable = true;
      extraConfig = ''ZSH_COMPDUMP="${cache}/completion"'';
      plugins = [
        "fancy-ctrl-z"
        "git-auto-fetch"
        "magic-enter"
        "sudo"
      ];
    };
  };
}
