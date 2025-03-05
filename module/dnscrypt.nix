{ pkgs, config, lib, ... }:
let
  inherit (lib)
    concatLines
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    ;
  inherit (lib.types)
    attrsOf
    bool
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
            };

            forwarding = {
              # default FRITZ!Box IP
              "fritz.box" = "192.168.178.1";
            };
          };
        };
      };

      networking.networkmanager.dns = "none";

      services = {
        resolved.enable = false;

        dnscrypt-proxy2 = {
          enable = true;
          upstreamDefaults = true;
          settings = {
            listen_addresses = [ "127.0.0.1:53" "[::1]:53" ];

            query_log.file = "/dev/stdout";

            ipv4_servers = true;
            ipv6_servers = true;

            http3 = true;

            dnscrypt_servers = true;
            doh_servers = false;
            odoh_servers = false;

            require_dnssec = true;
            require_nolog = true;
            require_nofilter = true;

            cache = true;
            cache_size = 100000;

            bootstrap_resolvers = [ "9.9.9.9:53" ];

            sources = {
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
                minisign_key = "RWQBphd2+f6eiAqBsvDZEBXBGHQBJfeG6G+wJPPKxCZMoEQYpmoysKUN";
                prefix = "quad9-";
                urls = [ "https://www.quad9.net/quad9-resolvers.md" ];
              };

              dnscry-pt-resolvers = {
                cache_file = "/var/cache/dnscrypt-proxy/dnscry.pt-resolvers.md";
                minisign_key = "RWQM31Nwkqh01x88SvrBL8djp1NH56Rb4mKLHz16K7qsXgEomnDv6ziQ";
                prefix = "dnscry.pt-";
                refresh_delay = 73;
                urls = [ "https://www.dnscry.pt/resolvers.md" ];
              };

              ####################

              relays = {
                cache_file = "/var/cache/dnscrypt-proxy/relays.md";
                minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
                refresh_delay = 73;
                urls = [
                  "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md"
                  "https://download.dnscrypt.info/resolvers-list/v3/relays.md"
                ];
              };
            };

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
      services.dnscrypt-proxy2.settings = {
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
      services.dnscrypt-proxy2.settings = {
        local_doh = {
          listen_addresses = [ "127.0.0.1:5353" "[::1]:5353" ];
          path = "/dns-query";

          cert_file = doh.crt;
          cert_key_file = "/run/credentials/dnscrypt-proxy2.service/key";
        };
      };

      systemd.services = {
        dnscrypt-proxy2 = {
          after = [ "dnscrypt-proxy2-doh.service" ];
          wants = [ "dnscrypt-proxy2-doh.service" ];

          serviceConfig.LoadCredential = [ "key:${doh.key}" ];
        };

        dnscrypt-proxy2-doh = {
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
  ]);
}
