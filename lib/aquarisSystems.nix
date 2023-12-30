{ inputs, nixosModules }: src: {
  nixosConfigurations = builtins.mapAttrs
    (name: cfg:
      let system = cfg.system or "x86_64-linux"; in
      inputs.nixpkgs.lib.nixosSystem rec {
        inherit system;
        specialArgs = inputs // { inherit src system; };
        modules = builtins.attrValues nixosModules ++ (
          let d = "${src}/machines/${name}"; in
          if !builtins.pathExists d then [ ] else [ import d ]
        ) ++ [{
          aquaris.machine = {
            inherit name;
            inherit (cfg) id publicKey;
            # merge admins and users
            users = builtins.mapAttrs (_: u: u // { isAdmin = true; })
              (cfg.admins or { }) // (cfg.users or { });
          };
        }];
      })
    ((import src).machines);
}
