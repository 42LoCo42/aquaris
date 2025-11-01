nixpkgs: pkgs: lib:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (pkgs.lib) getExe;

  mkKexec = crossSystem:
    let
      pkgsCross = import nixpkgs {
        localSystem = system;
        inherit crossSystem;
      };

      pkgsTarget = import nixpkgs {
        system = crossSystem;
      };

      kexec = pkgsCross.writeShellApplication {
        name = "kexec";

        runtimeInputs = with pkgsTarget; [
          curl
          gnutar
          iproute2
          jq
        ];

        text = lib.subsT ./kexec.sh {
          system = crossSystem;
        };
      };

      bundle = pkgs.runCommand "kexec-bundle" { } ''
        cat <<-\EOF > $out
        d="$(mktemp -d)"
        tail -n+6 "$0" | tar xz -C "$d" --strip-components 2
        mkdir -p /nix/store
        mount -t overlay -o "lowerdir=/nix/store:$d" aquaris-kexec /nix/store
        exec ${getExe kexec} "$@"
        EOF

        tar cz -T ${pkgs.writeClosure kexec} >> $out
      '';
    in
    bundle;

  deploy = pkgs.writeShellApplication {
    name = "deploy";

    runtimeInputs = with pkgs; [
      openssh
    ];

    text = lib.subsT ./deploy.sh {
      kexec-amd = mkKexec "x86_64-linux";
      kexec-arm = mkKexec "aarch64-linux";
    };
  };
in
deploy
