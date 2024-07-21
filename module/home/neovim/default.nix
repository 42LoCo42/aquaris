{ pkgs, mkEnableOption, ... }: {
  options.aquaris.neovim = "preconfigured neovim";

  config = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraConfig = builtins.readFile ./init.vim;
      extraLuaConfig = builtins.readFile ./nvim.lua;

      plugins = with pkgs.vimPlugins; [
        airline
        ale
        autoclose-nvim
        deoplete-nvim
        gitgutter
        gruvbox-nvim
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
