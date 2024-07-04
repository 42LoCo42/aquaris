nixpkgs:
let
  inherit (nixpkgs.lib)
    fileContents
    mapAttrsToList
    mkOption
    pipe
    recursiveUpdate
    splitString
    ;
  inherit (nixpkgs.lib.types)
    oneOf
    str
    submodule
    ;

  flake-utils = builtins.getFlake "github:numtide/flake-utils/b1d9ab70662946ef0850d488da1c9019f3a9752a?narHash=sha256-SZ5L6eA7HJ/nmkzGG7/ISclqe6oZdOZTNoesiInkXPQ%3D";
in
rec {
  inherit (flake-utils.lib) eachDefaultSystem;

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

  ##### Simple ADT library #####

  adt =
    let
      addTag = val: recursiveUpdate val {
        options._tag = mkOption {
          type = str;
          readOnly = true;
        };
      };

      mkModule =
        let
          gen = val:
            if builtins.isAttrs val
            then addTag val
            else if builtins.isFunction val
            then args: gen (val args)
            else if builtins.isPath val
            then gen (import val)
            else abort "unsupported ADT entry type ${builtins.typeOf val}";
        in
        val: submodule (gen val);

      mkType = choices: pipe choices [
        (mapAttrsToList (name: val:
          let mod = mkModule val; in
          mod // { check = v: mod.check v && v._tag == name; }
        ))
        oneOf
      ];

      adt = choices: pipe choices [
        (mapAttrsToList (name: _: {
          is.${name} = v: v._tag == name;
          mk."${name}" = v: recursiveUpdate v { _tag = name; };
          type = mkType choices;
        }))
        (builtins.foldl' recursiveUpdate { })
      ];
    in
    adt;
}
