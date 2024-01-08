inputs:
let
  inherit (inputs.nixpkgs.lib)
    mapAttrsToList
    pipe
    recursiveUpdate;
in
{
  my-utils = {
    mkHomeLinks = pairs: pipe pairs [
      (map (pair: ''
        mkdir -p "${dirOf pair.dst}"
        ln -sfT "${pair.src}" "${pair.dst}"
      ''))
      (builtins.concatStringsSep "\n")
      (inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ])
    ];
  };

  recMerge = builtins.foldl' recursiveUpdate { };

  substituteAll = file: vars:
    let
      pairs = mapAttrsToList (k: v: { inherit k v; }) vars;
      srcs = map (i: "@${i.k}@") pairs;
      dsts = map (i: toString i.v) pairs;
    in
    pipe file [
      builtins.readFile
      (builtins.replaceStrings srcs dsts)
    ];
}
