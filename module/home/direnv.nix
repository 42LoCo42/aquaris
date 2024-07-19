{ mkEnableOption, ... }: {
  options.aquaris.direnv = mkEnableOption "direnv and nix-direnv integration";

  config = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
