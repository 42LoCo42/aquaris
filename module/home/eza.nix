{ lib, config, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.eza;
in
{
  options.aquaris.eza = mkEnableOption "eza, a replacement for ls";

  config = mkIf cfg {
    programs.eza = {
      enable = true;
      extraOptions = [
        "--almost-all"
        "--group"
        "--group-directories-first"
        "--header"
        "--icons"
        "--long"
        "--mounts"
        "--total-size"
      ];
    };

    xdg.configFile."eza/theme.yml".text = builtins.toJSON {
      filenames = {
        # dot stuff in home
        ".cache".icon.glyph = "󰃨";
        ".librewolf".icon.glyph = "󰈹";
        ".local".icon.glyph = "󰆼";
        ".mozilla".icon.glyph = "󰈹";
        ".nv".icon.glyph = "󰢮";
        ".pki".icon.glyph = "󰌾";
        ".thunderbird".icon.glyph = "";
        ".zsh".icon.glyph = "";

        # main dirs in home
        "dev".icon.glyph = "";
        "doc".icon.glyph = "󰈙";
        "img".icon.glyph = "";
        "music".icon.glyph = "";
        "work".icon.glyph = "";

        # nixos config
        "homepage".icon.glyph = "󰖟";
        "images".icon.glyph = "";
        "keys".icon.glyph = "󰢬";
        "machines".icon.glyph = "";
        "rice".icon.glyph = "󰟪";
        "secrets".icon.glyph = "󰦝";

        # misc
        ".jj".icon.glyph = "󰘬";
        "Caddyfile".icon.glyph = "󰒒";
        "result".icon.glyph = "";
      };

      extensions = {
        "excalidraw".icon.glyph = "";
        "gpx".icon.glyph = "󰖃";
        "json".icon.glyph = "";
        "key".icon.glyph = "󰌆";
        "ora".icon.glyph = "";
        "prettierrc".icon.glyph = "";
        "pug".icon.glyph = "";
        "yaml".icon.glyph = "";
      };
    };
  };
}
