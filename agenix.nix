src: { agenix, pkgs, config, lib, ... }:
let
  inherit (lib) filterAttrs mapAttrs' mkOption pipe types;
  inherit (types) path;
  cfg = config.aquaris.agenix;
in
{
  options.aquaris.agenix = {
    keyPath = mkOption {
      type = path;
      default = "/etc/age.key";
    };

    secretsDir = mkOption {
      type = path;
      default = "${src}/secrets";
    };
  };

  imports = [ agenix.nixosModules.default ];

  config = {
    nixpkgs.overlays = [ src.inputs.agenix.overlays.default ];
    environment.systemPackages = [ pkgs.agenix ];

    age = {
      identityPaths = [ cfg.keyPath ];
      secrets =
        let
          keys = import "${cfg.secretsDir}/keys.nix";
          myPubKey = keys.machines.${config.networking.hostName};
          rules = import "${cfg.secretsDir}/secrets.nix";
        in
        pipe cfg.secretsDir [
          builtins.readDir
          (filterAttrs (name: type:
            type == "regular" &&
            builtins.match ".*\.age" name != null &&
            lib.any (k: k == myPubKey) rules.${name}.publicKeys
          ))
          (mapAttrs' (name: _: {
            name = builtins.replaceStrings [ ".age" ] [ "" ] name;
            value.file = "${cfg.secretsDir}/${name}";
          }))
        ];
    };
  };
}
