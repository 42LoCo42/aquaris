{ pkgs, config, mkEnableOption, ... }:
let cache = "$HOME/.cache/zsh"; in {
  options.aquaris.zsh = mkEnableOption "ZSH with OMZ and some plugins";

  config = {
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

      plugins = with pkgs; [
        (pkgs.lib.getAttrs [ "name" "src" ] zsh-fzf-history-search)
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
  };
}
