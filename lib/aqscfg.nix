{ nixpkgs, nixosConfigurations, keys }:
let
  inherit (nixpkgs.lib) pipe zipAttrs;

  getKey = m: m.config.aquaris.machine.key;

  toplevel = pipe nixosConfigurations [
    builtins.attrValues
    (map getKey)
  ];

  machine = builtins.mapAttrs
    (_: m: [ (getKey m) ])
    nixosConfigurations;

  user = pipe nixosConfigurations [
    builtins.attrValues
    (map (m: builtins.mapAttrs
      (_: _: getKey m)
      m.config.aquaris.users))
    zipAttrs
  ];
in
{ inherit toplevel machine user keys; }
