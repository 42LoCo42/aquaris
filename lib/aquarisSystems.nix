{ inputs, nixosModules }: src:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs.lib)
    mapAttrsToList
    nixosSystem
    pipe
    recursiveUpdate;
  recMerge = builtins.foldl' recursiveUpdate { };
in
pipe ((import src).machines) [
  (mapAttrsToList (name: cfg: {
    nixosConfigurations.${name} =
      let system = cfg.system or "x86_64-linux"; in nixosSystem {
        inherit system;

        specialArgs =
          inputs //
          (import ./utils.nix {
            pkgs = nixpkgs { inherit system; };
            inherit (inputs) home-manager;
          }) //
          { inherit src system; };

        modules = builtins.attrValues nixosModules ++
          (
            let d = "${src}/machines/${name}"; in
            if builtins.pathExists d then [ (import d) ] else [ ]
          ) ++
          [{
            aquaris = {
              # merge admins and users
              users = builtins.mapAttrs (_: u: u // { isAdmin = true; })
                (cfg.admins or { }) // (cfg.users or { });

              machine = {
                inherit name;
                inherit (cfg) id publicKey;
              };
            };
          }];
      };

    packages = pipe [ "x86_64-linux" ] [
      (map (system:
        let
          pkgs = import nixpkgs { inherit system; };

          installer = pkgs.writeShellScript "${name}-installer" ''
            ${inputs.disko.packages.${system}.disko}/bin/disko \
              -m disko -f '${src}#${name}'
          '';

          deployer = pkgs.writeShellScriptBin "${name}-deployer" ''
            host="root@192.168.122.195"
            nix copy ${installer} --to "ssh://$host"
            ssh "$host" <<-EOF
              ${installer}
            EOF
          '';
        in
        {
          ${system} = {
            "${name}" = deployer;
          };
          # program = getExe (pkgs.writeShellApplication {
          #   inherit name;
          #   runtimeInputs = with pkgs; [ ];
          #   text = ''
          #     ls ${inputs.disko.packages.${system}.disko}
          #   '';
          # });
        }))
      recMerge
    ];
  }))
  recMerge
]
