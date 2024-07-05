nixpkgs: pkgs: lib:
let
  inherit (pkgs) system;
  inherit (pkgs.lib) getExe;

  relocatable = builtins.getFlake "github:Ninlives/relocatable.nix/d8dbbb7a7749320a76f6d7c147d4332f6cba45bf?narHash=sha256-WxXa9Yca6LnsyhnMNPgoQHoxIMkVXvW5Q6bB00C8yis%3D";

  mkReloc = drv: (pkgs.callPackage relocatable { } drv).overrideAttrs {
    meta.mainProgram = "${drv.name}.deploy";
  };

  mkKexec = crossSystem:
    let
      pkgs' = import nixpkgs {
        localSystem = system;
        inherit crossSystem;
      };

      kexec = pkgs'.writeShellApplication {
        name = "kexec";

        runtimeInputs = with pkgs'; [
          curl
          gnutar
          iproute2
          jq
        ];

        text = lib.subsT ./kexec.sh {
          system = crossSystem;
        };
      };
    in
    getExe (mkReloc kexec);

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
