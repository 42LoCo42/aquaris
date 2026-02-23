{ pkgs, config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.neovim;
in
{
  options.aquaris.neovim = mkEnableOption "preconfigured neovim";

  config = mkIf cfg {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraConfig = builtins.readFile ./init.vim;
      ${if builtins.hasAttr "initLua" config.programs.neovim
      then "initLua" else "extraLuaConfig"} = builtins.readFile ./nvim.lua;

      plugins = with pkgs.vimPlugins; [
        ale
        autoclose-nvim
        deoplete-nvim
        gruvbox-nvim
        vim-airline
        vim-gitgutter
        vim-nix
        vim-suda
      ];
    };

    home.shellAliases = {
      vi = "vi -p";
      vim = "vim -p";
    };
  };
}
