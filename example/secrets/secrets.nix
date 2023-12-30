# NOTE: the template has a real aquaris import, this is just for easier debugging!
let aquaris = builtins.getFlake "path:/home/leonsch/dev/nix/aquaris"; in
aquaris.lib.secretsHelper ./..
