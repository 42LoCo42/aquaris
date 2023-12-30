# NOTE: you should use github:42loco42/aquaris/<commit>
# this is just for easier debugging!
let aquaris = builtins.getFlake "path:/home/leonsch/dev/nix/aquaris"; in
aquaris.lib.secretsHelper ./..
