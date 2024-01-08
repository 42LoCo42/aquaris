{ inputs, nixosModules }: src:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs.lib)
    getExe
    mapAttrsToList
    nixosSystem
    recursiveUpdate;

  recMerge = builtins.foldl' recursiveUpdate { };
  globalF = f: recMerge (mapAttrsToList f ((import src).machines));
  packagesF = f: recMerge (map f [ "x86_64-linux" ]);

  out = globalF (name: cfg: {
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

    packages = packagesF (system:
      let
        pkgs = import nixpkgs { inherit system; };

        installer = pkgs.writeShellApplication {
          name = "${name}-installer";
          runtimeInputs = with pkgs; [
            jq
            nix-output-monitor
          ];
          text = ''
            ${inputs.disko.packages.${system}.disko}/bin/disko \
              --no-deps -m disko -f "${src}#${name}"

            sys="$(nom build                                     \
              --extra-experimental-features "nix-command flakes" \
              --no-link --print-out-paths                        \
              "${src}#nixosConfigurations.${name}.config.system.build.toplevel")"

            nixos-install --no-channel-copy --no-root-password --system "$sys"
          '';
        };

        deployer = pkgs.writeShellApplication {
          name = "${name}-deployer";
          runtimeInputs = with pkgs; [ openssh ];
          text = ''
            host="root@192.168.122.195" # TODO
            nix copy ${installer} --to "ssh://$host"
            ssh -t "$host" ${getExe installer}
          '';
        };
      in
      {
        ${system} = {
          "${name}-installer" = installer;
          "${name}-deployer" = deployer;
        };
      });
  });
in
{
  inherit (out) nixosConfigurations packages;
}
