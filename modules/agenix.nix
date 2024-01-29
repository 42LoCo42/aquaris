{ pkgs, config, lib, src, agenix, ... }: {
  imports = [ agenix.nixosModules.default ];
  nixpkgs.overlays = [ agenix.overlays.default ];
  environment.systemPackages = [ pkgs.agenix ];

  age = {
    identityPaths = [ config.aquaris.machine.secretKey ];
    secrets =
      let d = "${src}/secrets"; in
      with lib; pipe "${d}/secrets.nix" [
        import
        (filterAttrs (_: val:
          any (k: k == config.aquaris.machine.publicKey) val.publicKeys))
        (mapAttrs' (name: _: {
          name = builtins.replaceStrings [ ".age" ] [ "" ] name;
          value = {
            file = "${d}/${name}";
            owner =
              let u = builtins.match "users/([^/]+)/.*" name; in
              if u != null then builtins.head u else "0";
          };
        }))
      ];
  };
}
