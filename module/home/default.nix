{ pkgs, lib, config, specialArgs, aquaris, ... }:
let
  inherit (lib) ifEnable mkOption;
  inherit (lib.types) bool;
in
{
  imports = [ aquaris.inputs.home-manager.nixosModules.default ];

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

    ##### load HM vars globally #####

    environment.extraInit =
      let file = ''"/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"''; in ''
        if [ -f ${file} ]; then source ${file}; fi
      '';

    ##### global settings for zsh submodule #####

    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;

      shellInit = ''
        export ZDOTDIR="$HOME/.config/zsh"
      '';
    };

    users.users = builtins.mapAttrs
      (_: x: ifEnable x.aquaris.zsh { shell = pkgs.zsh; })
      config.home-manager.users;
  };
}
