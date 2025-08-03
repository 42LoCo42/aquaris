{ pkgs, config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkAfter mkIf mkMerge versionAtLeast;
  cfg = config.aquaris.zsh;
  cache = "${config.xdg.cacheHome}/zsh";
in
{
  options.aquaris.zsh = mkEnableOption "ZSH with OMZ and some plugins";

  config = mkIf cfg {
    home = {
      packages = with pkgs; [ fzf jq ];

      file = mkMerge [
        { ".zshenv".enable = false; }
        (mkIf (!versionAtLeast config.home.version.release "25.11") {
          "${config.xdg.configHome}/zsh/.zshenv".text = mkAfter ''
            export ZDOTDIR="${config.xdg.configHome}/zsh"
          '';
        })
      ];
    };

    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      autocd = true;
      defaultKeymap = "emacs";

      history = {
        append = true;
        extended = true;
        ignoreAllDups = true;
        ignorePatterns = [ "l" "n" ];

        path = "${cache}/history";
      };

      ${if builtins.hasAttr "initContent" config.programs.zsh
      then "initContent" else "initExtra"} = ''
        # help for builtins
        unalias run-help
        autoload run-help
        alias help=run-help

        bindkey "[1;3C" forward-word
        bindkey "[1;3D" backward-word

        # https://github.com/zsh-users/zsh-syntax-highlighting/issues/295#issuecomment-214581607
        zstyle ':bracketed-paste-magic' active-widgets '.self-*'

        # fuzzy completion - https://superuser.com/a/815317
        zstyle ':completion:*' matcher-list ''' \
          'm:{a-z\-}={A-Z\_}' \
          'r:[^[:alpha:]]||[[:alpha:]]=** r:|=* m:{a-z\-}={A-Z\_}' \
          'r:|?=** m:{a-z\-}={A-Z\_}'
      '';

      plugins = with pkgs; [
        {
          name = "jq";
          inherit (jq-zsh-plugin) src;
        }

        {
          name = "zsh-fzf-history-search";
          inherit (zsh-fzf-history-search) src;
        }
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
