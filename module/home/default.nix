{ pkgs, lib, config, specialArgs, aquaris, home-manager, ... }:
let
  inherit (lib) ifEnable mkOption;
  inherit (lib.types) bool;
in
{
  imports = [ home-manager.nixosModules.default ];

  config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users = builtins.mapAttrs
        (_: _: {
          home = { inherit (config.system) stateVersion; };
        })
        config.aquaris.users;

      extraSpecialArgs = specialArgs // {
        mkEnableOption = what: mkOption {
          description = "Enable ${what}";
          type = bool;
          default = true;
        };
      };

      sharedModules = aquaris.lib.importDir ./.;
    };

    ##### global settings for zsh submodule #####

    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };

    users.users = builtins.mapAttrs
      (_: x: ifEnable x.aquaris.zsh { shell = pkgs.zsh; })
      config.home-manager.users;
  };
}
