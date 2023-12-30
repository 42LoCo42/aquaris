let aquaris = builtins.getFlake "github:42loco42/aquaris/b15ac3c"; in
aquaris.lib.secretsHelper ./..
