# import all *.nix files except flake.nix
{ self, nixpkgs }:
with builtins; with nixpkgs.lib; pipe self [
  readDir
  (filterAttrs (name: type:
    type == "regular" && name != "flake.nix" && match ".*\.nix" name != null))
  attrNames
  (map (name: {
    name = replaceStrings [ ".nix" ] [ "" ] name;
    value = import "${self}/${name}";
  }))
  listToAttrs
]
