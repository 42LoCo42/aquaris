{ self, nixpkgs }:
with builtins; with nixpkgs.lib; pipe "${self}/modules" [
  readDir
  attrNames
  (map (name: {
    name = replaceStrings [ ".nix" ] [ "" ] name;
    value = import "${self}/modules/${name}";
  }))
  listToAttrs
]
