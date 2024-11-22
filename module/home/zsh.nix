{ pkgs, config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.zsh;
  cache = "$HOME/.cache/zsh";
in
{
  options.aquaris.zsh = mkEnableOption "ZSH with OMZ and some plugins";

  config = mkIf cfg {
    home.file = {
      ".profile".text = ''
        source "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
      '';

      ".zshenv".enable = false;
    };

    programs.zsh = {
      enable = true;
      dotDir = ".config/zsh";

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
        extraConfig = ''
          MAGIC_ENTER_GIT_COMMAND=' git status'
          MAGIC_ENTER_OTHER_COMMAND=' ls -lh'

          ZSH_COMPDUMP="${cache}/completion"
        '';
        plugins = [
          "fancy-ctrl-z"
          "magic-enter"
          "sudo"
        ];
      };
    };
  };
}
