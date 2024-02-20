{ self, nixpkgs }:
with builtins; with nixpkgs.lib; pipe "${self}/modules" [
  readDir
  (filterAttrs (_: type: type == "regular"))
  attrNames
  (map (name: {
    name = replaceStrings [ ".nix" ] [ "" ] name;
    value = import "${self}/modules/${name}";
  }))
  listToAttrs
]
