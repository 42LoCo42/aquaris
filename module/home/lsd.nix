{ mkEnableOption, ... }: {
  options.aquaris.lsd = mkEnableOption "lsd, a better ls";

  config = {
    programs.lsd = {
      enable = true;
      enableAliases = true;
      settings = {
        sorting.dir-grouping = "first";
      };
    };
  };
}
