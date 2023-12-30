let
  f = builtins.fromJSON (builtins.readFile ../flake.lock);
  n = f.nodes.${f.nodes.${f.root}.inputs.aquaris}.locked;
  aquaris = builtins.getFlake "${n.type}:${n.owner}/${n.repo}/${n.rev}";
in
aquaris.lib.secretsHelper ./..
