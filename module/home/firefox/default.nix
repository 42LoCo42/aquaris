{ pkgs, lib, config, osConfig, aquaris, ... }:
let
  inherit (lib)
    concatMapAttrsStringSep
    defaultTo
    filterAttrs
    getExe
    getExe'
    mkIf
    mkMerge
    mkOption
    pipe
    removePrefix
    ;

  inherit (lib.types)
    attrsOf
    bool
    coercedTo
    enum
    int
    lines
    nullOr
    oneOf
    package
    port
    str
    submodule
    ;

  cfg = config.aquaris.firefox;
  inherit (osConfig.aquaris) dnscrypt;

  forks = enum [ "firefox" "librewolf" ];

  dir = "${config.programs.${cfg.fork}.configPath}/default";

  json = (pkgs.formats.json { }).type;
  pref = oneOf [ bool int str ];
in
{
  options.aquaris.firefox = {
    enable = mkOption {
      type = bool;
      description = "Enable advanced Firefox configuration";
      default = false;
    };

    fork = mkOption {
      type = coercedTo (nullOr forks) (defaultTo "firefox") forks;
      description = "Which fork to use";
      default = "librewolf";
    };

    package = mkOption {
      type = package;
      description = "The Firefox package to use";
      default = pkgs.${cfg.fork};
    };

    #####

    extensions = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          url = mkOption {
            type = str;
            description = "Where to download the extension .xpi from";
            default = "https://addons.mozilla.org/firefox/downloads/latest/${name}/latest.xpi";
          };

          pin = mkOption {
            type = bool;
            description = "Whether to pin the extension to the navbar";
            default = false;
          };

          private = mkOption {
            type = bool;
            description = "Whether to run this extension in private windows";
            default = false;
          };
        };
      }));
      description = "Enabled extensions. Key = Extension ID";
      default = { };
    };

    extraPrefs = mkOption {
      type = lines;
      description = "Extra preference code";
      default = "";
    };

    prefs = mkOption {
      type = attrsOf (nullOr (coercedTo pref (x: { value = x; }) (submodule {
        options = {
          value = mkOption { type = json; };
          locked = mkOption { type = bool; default = true; };
        };
      })));
      description = "Preferences to set via global autoconfiguration";
      default = { };
    };

    # https://mozilla.github.io/policy-templates
    policies = mkOption {
      type = json;
      description = "Global Policies (passed to equivalent home-manager option)";
      default = { };
    };

    userChrome = mkOption {
      type = lines;
      description = ''
        Contents of userChrome.css.
        Will be copied into your profile on every launch to support sync tools.
      '';
      default = "";
    };

    #####

    captivePortal = {
      enable = mkOption {
        type = bool;
        description = "Support secure captive portal logins using https://github.com/FiloSottile/captive-browser";
        default = true;
      };

      url = mkOption {
        type = str;
        description = "This URL will be opened in a private window to test connectivity";
        default = "http://neverssl.com";
      };

      getDNS = mkOption {
        type = str;
        description = "Command that returns the fallback DNS IP";
        default = "${getExe' pkgs.networkmanager "nmcli"} device show | grep IP4.DNS";
      };

      port = mkOption {
        type = port;
        description = "Port of the SOCKS5 proxy";
        default = 1666;
      };
    };

    settings = {
      bitwarden = mkOption {
        type = bool;
        description = "Use Bitwarden instead of the builtin password manager";
        default = true;
      };

      harden = mkOption {
        type = bool;
        description = "Configures a bunch of security-related settings";
        default = true;
      };

      noMozilla = mkOption {
        type = bool;
        description = "Disable Mozilla services & telemetry";
        default = true;
      };

      qol = mkOption {
        type = bool;
        description = "Enable some quality-of-life things";
        default = true;
      };

      ui = {
        invert = mkOption {
          type = bool;
          description = "Hide instead of show selected elements";
          default = false;
        };
      } // (pipe [
        "pageNext"
        "pagePrev"
        "pageReload"
        "tabAll"
        "tabClose"
        "tabNew"
        "tabNext"
        "tabPrev"
        "toolBarSpace"
        "windowClose"
      ] [
        (map (x: {
          name = x;
          value = mkOption {
            type = bool;
            default = false;
          };
        }))
        builtins.listToAttrs
      ]);
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      aquaris.firefox = {
        extraPrefs = mkMerge [
          ((concatMapAttrsStringSep "\n" (k: v:
            if v == null then "clearPref(${builtins.toJSON k});" else
            ((if v.locked then "lockPref" else "defaultPref") +
              "(${builtins.toJSON k}, ${builtins.toJSON v.value});")
          )) cfg.prefs)

          (pipe cfg.extensions [
            (filterAttrs (_: x: x.private))
            builtins.attrNames
            (x: mkIf (x != [ ]) (pipe x [
              builtins.toJSON
              (x: aquaris.lib.subsT ./privext.js { inherit x; })
            ]))
          ])
        ];

        prefs = {
          # show search suggestions
          "browser.search.suggest.enabled" = true;
          "browser.search.suggest.enabled.private" = false; # except in private windows
          "browser.urlbar.showSearchSuggestionsFirst" = true;
          "browser.urlbar.suggest.searches" = true;

          # use default search engine in private windows
          "browser.search.separatePrivateDefault" = false;

          # keep data on shutdown
          "privacy.clearOnShutdown_v2.cache" = false;
          "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
          "privacy.sanitize.sanitizeOnShutdown" = false;

          # remember history
          "browser.formfill.enable" = true;
          "places.history.enabled" = true;
          "privacy.history.custom" = false;

          # no "primary" clipboard
          "clipboard.autocopy" = false;
          "middlemouse.paste" = false;

          # update extensions automatically
          "extensions.update.autoUpdateDefault" = true;
          "extensions.update.enabled" = true;

          # enable userChrome
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };

        policies = {
          AutofillAddressEnabled = true;

          DisableProfileRefresh = true;
          DisableSetDesktopBackground = true;
          DontCheckDefaultBrowser = true;

          ExtensionSettings = (builtins.mapAttrs (_: cfg: {
            installation_mode = "force_installed";
            install_url = cfg.url;
            default_area = if cfg.pin then "navbar" else "menupanel";
          })) cfg.extensions;

          ExtensionUpdate = true;

          FirefoxHome = {
            Locked = true;
            Search = true;
            SponsoredTopSites = false;
          };

          NoDefaultBookmarks = true;

          OverrideFirstRunPage = "";

          SearchBar = "unified";
          ShowHomeButton = false;
        };

        userChrome =
          let
            inherit (cfg.settings) ui;
            mkHide = x: mkIf (if ui.invert then x else !x);

            displayNone = x: "${x} { display: none !important; }";
            widthZero = x: "${x} { width: 0 !important; }";
          in
          mkMerge [
            (mkHide ui.pageNext (displayNone "#forward-button"))
            (mkHide ui.pagePrev (displayNone "#back-button"))
            (mkHide ui.pageReload (mkMerge [
              (displayNone "#reload-button")
              (displayNone "#stop-button")
            ]))
            (mkHide ui.tabAll (displayNone "#alltabs-button"))
            (mkHide ui.tabClose (displayNone ".tab-close-button"))
            (mkHide ui.tabNew (mkMerge [
              # for some reason there are two???
              (displayNone "#new-tab-button")
              (displayNone "#tabs-newtab-button")
            ]))
            (mkHide ui.tabNext (displayNone "#scrollbutton-down"))
            (mkHide ui.tabPrev (displayNone "#scrollbutton-up"))
            (mkHide ui.toolBarSpace (displayNone "toolbarspring"))
            (mkHide ui.windowClose (mkMerge [
              (displayNone ".titlebar-buttonbox-container")
              (widthZero ''.titlebar-spacer[type="post-tabs"]'')
            ]))
          ];
      };

      aquaris.persist = {
        ${dir} = { };
        ".cache/${removePrefix "." dir}" = { };
      };

      programs.${cfg.fork} = {
        enable = true;

        package = cfg.package.override {
          extraPrefs = ''
            ${cfg.extraPrefs}
            EOF
            # terminate extraPrefs early; this leaves a hanging EOF

            # extract everything but the first line (exec) from the launcher
            file="$out/bin/${cfg.package.meta.mainProgram}"
            head -n-1 "$file" > tmp

            # on launch: copy userChrome.css to the current user's profile
            cat <<\EOF >> tmp
            file="$HOME/${config.programs.${cfg.fork}.configPath}/default/chrome/userChrome.css"
            mkdir -p "$(dirname "$file")"
            rm -f "$file"
            cp ${pkgs.writeText "userChrome.css" cfg.userChrome} "$file"
            EOF

            # finalize the launcher
            tail -n 1 "$file" >> tmp
            mv tmp "$file"
            chmod +x "$file"

            # catch the hanging EOF
            cat << EOF >/dev/null
          '';
        };

        inherit (cfg) policies;

        profiles.default = { };
      };
    }

    (mkIf cfg.settings.bitwarden {
      aquaris.firefox = {
        extensions = {
          "{446900e4-71c2-419f-a6a7-df9c091e268b}".pin = true; # https://addons.mozilla.org/en-US/firefox/addon/bitwarden-password-manager
        };

        policies = {
          AutofillCreditCardEnabled = false;
          DisableMasterPasswordCreation = true;
          OfferToSaveLogins = false;
          PasswordManagerEnabled = false;
        };
      };
    })

    (mkIf cfg.captivePortal.enable {
      aquaris.firefox = {
        extraPrefs = ''
          if (getenv("CAPTIVE_PORTAL") === "1") {
            lockPref("network.proxy.type", 1);
            lockPref("network.proxy.socks", "127.0.0.1");
            lockPref("network.proxy.socks_port", ${toString cfg.captivePortal.port});
            lockPref("network.proxy.socks5_remote_dns", true);
          }
        '';

        policies.HttpAllowlist = [ cfg.captivePortal.url ];
      };

      home.packages = with pkgs; [ captive-browser ];

      xdg = {
        configFile."captive-browser.toml".text = ''
          browser = "${builtins.concatStringsSep " " [
            "env CAPTIVE_PORTAL=1"
            (getExe config.programs.${cfg.fork}.finalPackage)
            "--private-window ${cfg.captivePortal.url}"
          ]}"
          dhcp-dns = "${cfg.captivePortal.getDNS}"
          socks5-addr = "127.0.0.1:${toString cfg.captivePortal.port}"
        '';

        desktopEntries.captive-portal = {
          name = "Captive Portal Login";
          icon = cfg.fork;
          exec = getExe' pkgs.captive-browser "captive-browser";
          terminal = true;
        };
      };
    })

    (mkIf cfg.settings.harden {
      aquaris.firefox = {
        extensions = {
          # https://addons.mozilla.org/en-US/firefox/addon/canvasblocker
          "CanvasBlocker@kkapsner.de" = {
            private = true;
          };

          # https://addons.mozilla.org/en-US/firefox/addon/ublock-origin
          "uBlock0@raymondhill.net" = {
            pin = true;
            private = true;
          };

          # https://addons.mozilla.org/en-US/firefox/addon/localcdn-fork-of-decentraleyes
          "{b86e4813-687a-43e6-ab65-0bde4ab75758}" = {
            private = true;
          };
        };

        prefs = {
          # Enhanced Tracking Protection -> Suspected fingerprinters: In all windows
          "privacy.fingerprintingProtection" = true;
          "privacy.fingerprintingProtection.pbmode" = true;

          # Block dangerous and deceptive content
          "browser.safebrowsing.downloads.enabled" = true;
          "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = true;
          "browser.safebrowsing.downloads.remote.block_uncommon" = true;
          "browser.safebrowsing.malware.enabled" = true;
          "browser.safebrowsing.phishing.enabled" = true;

          # Query OCSP responder servers...
          "security.OCSP.enabled" = 1;
          "security.OCSP.require" = true;
        };

        policies = {
          Certificates.Install = mkIf dnscrypt.localDoH
            [ osConfig.services.dnscrypt-proxy2.settings.local_doh.cert_file ];

          Cookies = {
            Behavior = "reject-foreign";
            Locked = true;
          };

          DNSOverHTTPS = {
            Locked = true;
            Fallback = false;

            ExcludedDomains = pipe dnscrypt.rules [
              (x: x.cloaking // x.forwarding)
              builtins.attrNames
            ];
          } //
          (if dnscrypt.enable then
            (if dnscrypt.localDoH then {
              # connect to dnscrypt via DoH
              Enabled = true;
              ProviderURL = "https://localhost:5353/dns-query";
            } else { Enabled = false; }) # connect to dnscrypt normally
          else { Enabled = true; }); # use default DoH provider

          EnableTrackingProtection = {
            Value = true;
            Locked = true;

            Cryptomining = true;
            EmailTracking = true;
            Fingerprinting = true;
          };

          EncryptedMediaExtensions = {
            Enabled = false;
            Locked = true;
          };

          HttpsOnlyMode = "force_enabled";

          PopupBlocking = {
            Allow = [ ];
            Default = true;
            Locked = true;
          };

          PostQuantumKeyAgreementEnabled = true;

          Preferences = {
            # Tell websites not to sell or share my data
            "privacy.globalprivacycontrol.enabled" = {
              Type = "boolean";
              Value = true;
              Status = "locked";
            };

            # DO NOT Show alerts about passwords for breached websites
            "signon.management.page.breach-alerts.enabled" = {
              Type = "boolean";
              Value = false;
              Status = "locked";
            };

            # Warn you when websites try to install add-ons
            "xpinstall.whitelist.required" = {
              Type = "boolean";
              Value = true;
              Status = "locked";
            };
          };
        };
      };
    })

    (mkIf cfg.settings.noMozilla {
      aquaris.firefox = {
        prefs = {
          # DO NOT Allow Firefox to send backlogged crash reports on your behalf
          "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
        };

        policies = {
          DisableFeedbackCommands = true; # report deceptive sites
          DisableFirefoxAccounts = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;

          FirefoxHome = {
            Pocket = false;
            SponsoredPocket = false;
          };

          FirefoxSuggest = {
            Locked = true;

            ImproveSuggest = false;
            SponsoredSuggestions = false;
            WebSuggestions = false;
          };

          UserMessaging = {
            Locked = true;

            ExtensionRecommendations = false;
            FeatureRecommendations = false;
            FirefoxLabs = false;
            MoreFromMozilla = false;
            SkipOnboarding = false;
            UrlbarInterventions = false;
          };
        };
      };
    })

    (mkIf cfg.settings.qol {
      aquaris.firefox = {
        extensions = {
          "addon@darkreader.org".pin = true; # https://addons.mozilla.org/en-US/firefox/addon/darkreader
          "hide-tabs@afnankhan".pin = true; # https://addons.mozilla.org/en-US/firefox/addon/hide-tab
          "idcac-pub@guus.ninja" = { }; # https://addons.mozilla.org/en-US/firefox/addon/istilldontcareaboutcookies
          "sponsorBlocker@ajay.app" = { }; # https://addons.mozilla.org/en-US/firefox/addon/sponsorblock
          "{0d7cafdd-501c-49ca-8ebb-e3341caaa55e}" = { }; # https://addons.mozilla.org/en-US/firefox/addon/youtube-nonstop
          "{4c421bb7-c1de-4dc6-80c7-ce8625e34d24}" = { }; # https://addons.mozilla.org/en-US/firefox/addon/load-reddit-images-directly
        };

        prefs = {
          # don't warn when opening about:config
          "browser.aboutConfig.showWarning" = false;

          # enable browser toolbox
          "devtools.chrome.enabled" = true;
          "devtools.debugger.remote-enabled" = true;

          # Open previous windows and tabs
          "browser.startup.page" = 3;

          # Use recommended performance settings
          "browser.preferences.defaultPerformanceSettings.enabled" = true;
          "layers.acceleration.disabled" = false;
        };

        policies = {
          DisplayBookmarksToolbar = "never";
          DisplayMenuBar = "never";

          FirefoxHome = {
            Highlights = false;
            Snippets = false;
            TopSites = false;
          };

          HardwareAcceleration = true;

          Homepage = {
            StartPage = "previous-session";
            Locked = true;
          };

          PictureInPicture = {
            Enabled = false;
            Locked = true;
          };
        };
      };
    })
  ]);
}
