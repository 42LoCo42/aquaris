{ config, lib, aquaris, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.tmux;
in
{
  options.aquaris.tmux = mkEnableOption "preconfigured tmux";

  config = mkIf cfg {
    programs.tmux = {
      enable = true;

      clock24 = true;
      escapeTime = 300;
      historyLimit = 10000;
      keyMode = "vi";
      mouse = true;
      shortcut = "w";
      terminal = "tmux-256color";

      extraConfig = aquaris.lib.subsT ./tmux.conf {
        split = "${./split.sh}";
      };
    };
  };
}
