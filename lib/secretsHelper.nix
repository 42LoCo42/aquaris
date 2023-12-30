src:
let
  nixpkgs =
    let
      f = builtins.fromJSON (builtins.readFile ./../flake.lock);
      n = f.nodes.${f.nodes.${f.root}.inputs.nixpkgs}.locked;
    in
    builtins.getFlake "${n.type}:${n.owner}/${n.repo}/${n.rev}";
  inherit (nixpkgs.lib) filterAttrs mapAttrs' mapAttrsToList pipe;
  inherit (nixpkgs.lib.attrsets) mergeAttrsList;

  inherit (import src) users machines;

  getKeys = set: pipe set [
    builtins.attrValues
    (map (i: i.publicKey))
  ];

  allKeys = getKeys users ++ getKeys machines;

  # all *.age files -> encrypted for all keys (users & machines)
  toplevel = pipe "${src}/secrets" [
    builtins.readDir
    (filterAttrs (name: type:
      type == "regular" && builtins.match ".*\.age" name != null))
    (builtins.mapAttrs (_: _: { publicKeys = allKeys; }))
  ] // { "empty.age".publicKeys = allKeys; }; # always include empty.age

  dirSecrets = { type, set, keyFn }: pipe set [
    (mapAttrsToList (name: item:
      let d = "${src}/secrets/${type}/${name}"; in
      if !builtins.pathExists d then { } else
      pipe d [
        builtins.readDir
        (mapAttrs' (secName: _: {
          name = "${type}/${name}/${secName}";
          value.publicKeys = keyFn item;
        }))
      ]
    ))
    mergeAttrsList
  ];

  # "user/<name>/<secret>.age" -> encrypted for that user & their machines
  # (those on which they are admin or a normal user)
  userSecrets = dirSecrets {
    type = "users";
    set = users;
    keyFn = user: pipe machines [
      (filterAttrs (_: m: builtins.any (u: u == user)
        (builtins.attrValues (m.admins or { } // m.users or { }))))
      getKeys
    ] ++ [ user.publicKey ];
  };

  # "machine/<name>/<secret.age>" -> encrypted for that machine & its admin
  machineSecrets = dirSecrets {
    type = "machines";
    set = machines;
    keyFn = machine: pipe machine.admins [
      builtins.attrValues
      (map (a: a.publicKey))
    ] ++ [ machine.publicKey ];
  };
in
toplevel // userSecrets // machineSecrets
