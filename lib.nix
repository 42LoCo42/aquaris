{ nixpkgs, ... }:
let
  inherit (nixpkgs.lib)
    fileContents
    mapAttrsToList
    pipe
    recursiveUpdate
    splitString
    ;
in
rec {
  merge = builtins.foldl' recursiveUpdate { };

  subsF = { file, func, subs ? { } }:
    let
      pairs = mapAttrsToList (k: v: { inherit k v; }) subs;
      srcs = map (i: "@${i.k}@") pairs;
      dsts = map (i: toString i.v) pairs;
    in
    pipe file [
      builtins.readFile
      (builtins.replaceStrings srcs dsts)
      (func (baseNameOf file))
    ];

  subsT = file: subs: subsF {
    inherit file subs;
    func = _: text: text;
  };

  readLines = file: pipe file [
    fileContents
    (splitString "\n")
  ];
}
