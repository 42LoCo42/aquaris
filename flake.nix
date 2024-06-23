{
  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs.lib) pipe filterAttrs nixosSystem;
      out = {
        nixosModules.default = import ./module;

        __functor = _: src: cfg:
          let
            nixosConfigurations =
              let
                # import every nix file in the machine config directory
                # add the aquaris module
                mkConfig = name: dir: pipe dir [
                  builtins.readDir
                  (filterAttrs (file: type:
                    type == "regular" && builtins.match ".*\.nix" file != null))
                  builtins.attrNames
                  (map (x: import "${dir}/${x}"))
                  (x: nixosSystem {
                    modules = x ++ [ out.nixosModules.default ];
                    specialArgs = self.inputs // {
                      aquaris = { inherit cfg name; };
                      self = src;
                    };

                    # system is set by the hardware config
                  })
                ];
                dir = "${src}/machines";
              in
              # mkConfig every directory in src/machines/
              pipe dir [
                builtins.readDir
                builtins.attrNames
                (map (name: {
                  inherit name;
                  value = mkConfig name "${dir}/${name}";
                }))
                builtins.listToAttrs
              ];
          in
          { inherit nixosConfigurations; };
      };
    in
    out // out self
      # shared config passed as aquaris.cfg to every machine
      # here used for shared user templates
      {
        users = rec {
          alice = {
            key = "foo";
          };

          bob = {
            key = "bar";
            extraKeys = [ alice.key ];
          };
        };
      };
}
