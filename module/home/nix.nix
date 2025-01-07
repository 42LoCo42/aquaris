{ pkgs, lib, config, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.nix;
in
{
  options.aquaris.nix = mkEnableOption "some useful aliases for Nix";

  config = mkIf cfg {
    home = {
      packages = with pkgs; [
        deadnix
        nix-output-monitor
        nix-tree
      ];

      shellAliases = {
        n = "nix repl"; # i use this often, so make it short!
        nb = "nom build";
        nch = "nix flake check -L"; # nc is netcat
        nd = "deadnix";
        ne = "nix eval -L";
        nej = "nix eval -L --raw --apply builtins.toJSON";
        ner = "nix eval -L --raw";
        ng = "nix store gc -v";
        ni = "nix flake init";
        nm = "nix flake metadata"; # nm exists, but is rarely used
        nn = "nix flake new";
        nr = "nix run -L";
        ns = "nix flake show";
        nt = "nix-tree";
        nu = "nix flake update";
      };
    };
  };
}
