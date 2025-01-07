{ self, lib, nixpkgs }: src0: cfg:
let
  inherit (nixpkgs.lib) filterAttrs nixosSystem pipe;

  src = src0 // { cfgDir = src0.cfgDir or src0.outPath; };

  nixosConfigurations =
    let
      # import every nix file in the machine config directory
      # add the aquaris module
      mkConfig = name: dir: nixosSystem {
        # system is set by the hardware config

        modules = lib.importDir'
          { default = true; dirs = false; }
          dir ++ [ ../module ];

        specialArgs = {
          aquaris = {
            inherit cfg lib name;
            inherit (self) inputs;
            src = self;
          };
          self = src;
        };
      };
      dir = "${src.cfgDir}/machines";
    in
    # mkConfig every directory in src/machines/
    pipe dir [
      builtins.readDir
      (filterAttrs (_: x: x == "directory"))
      builtins.attrNames
      (map (name: {
        inherit name;
        value = mkConfig name "${dir}/${name}";
      }))
      builtins.listToAttrs
    ];
in
{
  inherit nixosConfigurations;

  packages = pipe nixosConfigurations [
    builtins.attrValues
    (map (x:
      let installer = x.config.aquaris._installer; in
      { ${x.pkgs.system}.${installer.name} = installer; }))
    lib.merge
  ];
}
