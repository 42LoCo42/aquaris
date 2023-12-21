self: { config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (types) path;
  cfg = config.aquaris.agenix;
in
{
  options.aquaris.agenix = {
    keyPath = mkOption {
      type = path;
      default = "/etc/age.nix";
    };
  };

  config = {
    age = {
      identityPaths = [ cfg.keyPath ];

      secrets = lib.pipe "${self}/secrets/secrets.nix" [
        import
        builtins.attrNames
        (map (path: {
          name = builtins.replaceStrings [ ".age" ] [ "" ] path;
          value.file = "${self}/secrets/${path}";
        }))
        builtins.listToAttrs
      ];
    };
  };
}
