nixpkgs: { users, machines }:
let
  inherit (nixpkgs.lib)
    filterAttrs
    mapAttrsToList
    pipe;

  keysFor = o: [ o.publicKey or "" ] ++ (o.extraKeys or [ ]);

  getKeys = set: pipe set [
    builtins.attrValues
    (map keysFor)
    builtins.concatLists
  ];

  ##### toplevel: all keys #####

  toplevel = getKeys users ++ getKeys machines;

  ##### user secrets: for that user & the machines they are part of #####

  isUserInMachine = uN: m: pipe m [
    (m: builtins.attrNames ((m.admins or { }) // m.users or { }))
    (builtins.elem uN)
  ];

  machineKeysForUser = uN: pipe machines [
    (filterAttrs (_: isUserInMachine uN))
    (mapAttrsToList (_: keysFor))
    (builtins.concatLists)
  ];

  user = builtins.mapAttrs (uN: uV: keysFor uV ++ machineKeysForUser uN) users;

  ##### machine secrets: for that machine & its admins #####

  machine = builtins.mapAttrs
    (_: m: keysFor m ++ pipe (m.admins or { }) [
      (mapAttrsToList (_: keysFor))
      builtins.concatLists
    ])
    machines;
in
{ inherit toplevel user machine; }
