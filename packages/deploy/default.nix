pkgs: lib:
let
  inherit (pkgs.lib) getExe;

  # TODO kexec helper should be available for each architecture
  # deployer should get target arch and copy the corresponding helper

  kexec = pkgs.writeShellApplication {
    name = "kexec";

    runtimeInputs = with pkgs; [
      curl
      gnutar
      iproute2
      jq
    ];

    text = builtins.readFile ./kexec.sh;
  };

  deploy = pkgs.writeShellApplication {
    name = "deploy";

    runtimeInputs = with pkgs; [
      openssh
    ];

    text = lib.subsT ./deploy.sh {
      kexec = getExe (pkgs.relocatable kexec);
    };
  };
in
deploy
