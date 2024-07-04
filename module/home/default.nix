{ pkgs, config, lib, specialArgs, home-manager, ... }:
let
  inherit (lib) ifEnable mkIf mkOption pipe;
  inherit (lib.types) bool;

  mkEnableOption = what: mkOption {
    description = "Enable ${what}";
    type = bool;
    default = true;
  };

  cfg = config.aquaris.home;
in
{
  options.aquaris.home = {
    bat = mkEnableOption "bat for manpage rendering";
    direnv = mkEnableOption "direnv and nix-direnv integration";
    git = mkEnableOption "Git";
    htop = mkEnableOption "preconfigured htop";
    lsd = mkEnableOption "lsd, a better ls";
    misc = mkEnableOption "miscellaneous packages and settings";
    neofetch = mkEnableOption "a neofetch-like command";
    neovim = mkEnableOption "preconfigured neovim";
    starship = mkEnableOption "the Starship shell prompt";
    tmux = mkEnableOption "tmux";
    zsh = mkEnableOption "ZSH with OMZ and some plugins";
  };

  imports = [
    home-manager.nixosModules.default

    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;

        users = builtins.mapAttrs (_: _: { }) config.aquaris.users;

        extraSpecialArgs = specialArgs;
        sharedModules = [{
          home.stateVersion = config.system.stateVersion;

          imports = pipe [
            (ifEnable cfg.bat ./bat.nix)
            (ifEnable cfg.direnv ./direnv.nix)
            (ifEnable cfg.git ./git.nix)
            (ifEnable cfg.htop ./htop.nix)
            (ifEnable cfg.lsd ./lsd.nix)
            (ifEnable cfg.misc ./misc.nix)
            (ifEnable cfg.neofetch ./neofetch.nix)
            (ifEnable cfg.neovim ./neovim)
            (ifEnable cfg.starship ./starship.nix)
            (ifEnable cfg.tmux ./tmux)
            (ifEnable cfg.zsh ./zsh.nix)
          ] [
            (map (x: if x == null then [ ] else [ x ]))
            builtins.concatLists
          ];
        }];
      };
    }

    (mkIf cfg.zsh {
      programs.zsh = {
        enable = true;
        enableGlobalCompInit = false;
      };

      users.users = builtins.mapAttrs
        (_: _: { shell = pkgs.zsh; })
        config.aquaris.users;
    })
  ];
}
