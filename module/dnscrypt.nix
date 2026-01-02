{ aquaris, pkgs, config, lib, ... }:
let
  inherit (lib)
    concatLines
    ifEnable
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    ;
  inherit (lib.types)
    attrsOf
    bool
    enum
    listOf
    str
    ;

  cfg = config.aquaris.dnscrypt;

  doh = {
    __functor = _: x: "${config.aquaris.persist.root}/var/lib/dnscrypt-proxy2-doh.${x}";

    crt = doh "crt";
    key = doh "key";
  };
in
{
  options.aquaris.dnscrypt = {
    enable = mkOption {
      type = bool;
      description = "Enable dnscrypt-proxy";
      default = false;
    };

    protos = {
      dnscrypt = mkOption {
        type = bool;
        description = "Enable the usage of dnscrypt servers";
        default = true;
      };

      doh = mkOption {
        type = bool;
        description = "Enable the usage of DoH servers";
        default = true;
      };

      odoh = mkOption {
        type = bool;
        description = "Enable the usage of ODoH servers";
        default = false;
      };
    };

    anonDNS = {
      enable = mkOption {
        type = bool;
        description = "Enable anonymized DNS";
        default = false;
      };

      via = mkOption {
        type = listOf str;
        description = "List of relays to use for anonymized DNS";
      };

      ign = mkOption {
        type = listOf str;
        description = "List of resolvers to ignore according to `via`";
      };
    };

    localDoH = mkOption {
      type = bool;
      description = "Enable the local DoH server (e.g. for Firefox)";
      default = true;
    };

    rules = {
      blocking = mkOption {
        type = listOf str;
        description = "List of IPs to block";
        default = [ ];
      };

      cloaking = mkOption {
        type = attrsOf str;
        description = "Set of cloaking rules (domain -> IP)";
        default = { };
      };

      forwarding = mkOption {
        type = attrsOf str;
        description = "Set of forwarding rules (domain -> IP)";
        default = { };
      };
    };

    ui = {
      enable = mkOption {
        type = bool;
        description = "Enable the monitoring UI";
        default = true;
      };

      listenAddress = mkOption {
        type = str;
        description = "What address should the monitoring UI listen on?";
        default = "127.0.0.1:53080";
      };

      username = mkOption {
        type = str;
        description = "Username for logging into the monitoring UI";
        default = "";
      };

      password = mkOption {
        type = str;
        description = "Password for logging into the monitoring UI";
        default = "";
      };

      privacyLevel = mkOption {
        type = enum [ 0 1 2 ];
        description = ''
          Privacy level of the monitoring UI
          - 0: show all details including client IPs
          - 1: anonymize client IPs (default)
          - 2: aggregate data only (no individual queries or domains shown)
        '';
        default = 0;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      aquaris = {
        persist.dirs."/var/cache/private/dnscrypt-proxy" = { };

        dnscrypt = {
          rules = {
            blocking = [
              # Localhost rebinding protection
              "0.0.0.0"
              "127.0.0.*"

              # RFC1918 rebinding protection
              "10.*"
              "172.16.*"
              "172.17.*"
              "172.18.*"
              "172.19.*"
              "172.20.*"
              "172.21.*"
              "172.22.*"
              "172.23.*"
              "172.24.*"
              "172.25.*"
              "172.26.*"
              "172.27.*"
              "172.28.*"
              "172.29.*"
              "172.30.*"
              "172.31.*"
              "192.168.*"
            ];

            cloaking = {
              # custom localhost domains
              "local.host" = "127.0.0.1";
              "localhost" = "127.0.0.1";
            };

            forwarding = {
              # default FRITZ!Box IP
              "fritz.box" = "192.168.178.1";
            };
          };
        };
      };

      networking = {
        nameservers = [ "127.0.0.1" ];
        networkmanager.dns = "none";
        resolvconf.useLocalResolver = true;
      };

      services = {
        resolved.enable = false;

        dnscrypt-proxy = {
          enable = true;
          upstreamDefaults = true;

          settings = {
            listen_addresses = [ "127.0.0.1:53" "[::1]:53" ];

            query_log.file = "/dev/stdout";

            ipv4_servers = true;
            ipv6_servers = true;

            http3 = true;

            dnscrypt_servers = cfg.protos.dnscrypt;
            doh_servers = cfg.protos.doh;
            odoh_servers = cfg.protos.odoh;

            require_dnssec = true;
            require_nolog = true;
            require_nofilter = true;

            cache = true;
            cache_size = 1000000;

            bootstrap_resolvers = [
              "9.9.9.9:53"
              "149.112.112.112:53"
              "1.1.1.1:53"
            ];

            sources = aquaris.lib.merge [
              (ifEnable (cfg.protos.dnscrypt) {
                dnscry-pt-resolvers = {
                  cache_file = "/var/cache/dnscrypt-proxy/dnscry.pt-resolvers.md";
                  minisign_key = "RWQM31Nwkqh01x88SvrBL8djp1NH56Rb4mKLHz16K7qsXgEomnDv6ziQ";
                  prefix = "dnscry.pt-";
                  refresh_delay = 73;
                  urls = [ "https://www.dnscry.pt/resolvers.md" ];
                };
              })

              (ifEnable (cfg.protos.dnscrypt || cfg.protos.doh) {
                public-resolvers = {
                  cache_file = "/var/cache/dnscrypt-proxy/public-resolvers.md";
                  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
                  refresh_delay = 73;
                  urls = [
                    "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
                    "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
                  ];
                };

                quad9-resolvers = {
                  cache_file = "/var/cache/dnscrypt-proxy/quad9-resolvers.md";
                  minisign_key = "RWTp2E4t64BrL651lEiDLNon+DqzPG4jhZ97pfdNkcq1VDdocLKvl5FW";
                  prefix = "quad9-";
                  urls = [
                    "https://raw.githubusercontent.com/Quad9DNS/dnscrypt-settings/main/dnscrypt/quad9-resolvers.md"
                    "https://quad9.net/dnscrypt/quad9-resolvers.md"
                  ];
                };
              })

              (ifEnable (cfg.protos.dnscrypt && cfg.anonDNS.enable) {
                relays = {
                  cache_file = "/var/cache/dnscrypt-proxy/relays.md";
                  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
                  refresh_delay = 73;
                  urls = [
                    "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md"
                    "https://download.dnscrypt.info/resolvers-list/v3/relays.md"
                  ];
                };
              })

              (ifEnable (cfg.protos.odoh && cfg.anonDNS.enable) {
                odoh-servers = {
                  cache_file = "/var/cache/dnscrypt-proxy/odoh-servers.md";
                  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
                  refresh_delay = 73;
                  urls = [
                    "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-servers.md"
                    "https://download.dnscrypt.info/resolvers-list/v3/odoh-servers.md"
                  ];
                };

                odoh-relays = {
                  cache_file = "/var/cache/dnscrypt-proxy/odoh-relays.md";
                  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
                  refresh_delay = 73;
                  urls = [
                    "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-relays.md"
                    "https://download.dnscrypt.info/resolvers-list/v3/odoh-relays.md"
                  ];
                };
              })
            ];

            blocked_ips.blocked_ips_file = pipe cfg.rules.blocking [
              concatLines
              (pkgs.writeText "blocking-rules.txt")
            ];

            cloaking_rules = pipe cfg.rules.cloaking [
              (mapAttrsToList (k: v: "${k} ${v}"))
              concatLines
              (pkgs.writeText "cloaking-rules.txt")
            ];

            forwarding_rules = pipe cfg.rules.forwarding [
              (mapAttrsToList (k: v: "${k} ${v}"))
              concatLines
              (pkgs.writeText "forwarding-rules.txt")
            ];
          };
        };
      };
    }

    (mkIf cfg.anonDNS.enable {
      services.dnscrypt-proxy.settings = {
        anonymized_dns = {
          routes = [{
            server_name = "*";
            inherit (cfg.anonDNS) via;
          }];

          skip_incompatible = true;
        };

        disabled_server_names = cfg.anonDNS.ign;
      };
    })

    (mkIf cfg.localDoH {
      services.dnscrypt-proxy.settings = {
        local_doh = {
          listen_addresses = [ "127.0.0.1:853" "[::1]:853" ];
          path = "/dns-query";

          cert_file = doh.crt;
          cert_key_file = "/run/credentials/dnscrypt-proxy.service/key";
        };
      };

      systemd.services = {
        dnscrypt-proxy = {
          after = [ "dnscrypt-proxy-doh.service" ];
          wants = [ "dnscrypt-proxy-doh.service" ];

          serviceConfig.LoadCredential = [ "key:${doh.key}" ];
        };

        dnscrypt-proxy-doh = {
          path = with pkgs; [ openssl ];

          script = ''
            if [ -f ${doh.crt} ] && [ -f ${doh.key} ]; then exit; fi

            openssl req                                \
              -newkey ec                               \
              -pkeyopt ec_paramgen_curve:secp521r1     \
              -noenc                                   \
              -keyout ${doh.key}                       \
              -x509                                    \
              -days 99999                              \
              -subj '/CN=dnscrypt-proxy2'              \
              -config <(:)                             \
              -addext 'subjectAltName = DNS:localhost' \
              -addext 'extendedKeyUsage = serverAuth'  \
              -out ${doh.crt}
          '';
        };
      };
    })

    (mkIf cfg.ui.enable {
      services.dnscrypt-proxy.settings = {
        monitoring_ui = {
          enabled = true;
          listen_address = cfg.ui.listenAddress;
          inherit (cfg.ui) username password;
          privacy_level = cfg.ui.privacyLevel;
        };
      };
    })
  ]);
}
