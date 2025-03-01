{ pkgs, lib, config, aquaris, ... }:
let
  inherit (lib)
    concatMapAttrsStringSep
    filterAttrs
    mkIf
    mkMerge
    mkOption
    pipe
    ;

  inherit (lib.types)
    attrsOf
    bool
    int
    lines
    oneOf
    package
    str
    submodule
    ;

  cfg = config.aquaris.firefox;
in
{
  options.aquaris.firefox = {
    enable = mkOption {
      type = bool;
      description = "Enable advanced Firefox configuration";
      default = false;
    };

    package = mkOption {
      type = package;
      description = "The Firefox package to use";
      default = pkgs.firefox;
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
      type = attrsOf (oneOf [ bool int str ]);
      description = "Preferences to set via global autoconfiguration";
      default = { };
    };

    # https://mozilla.github.io/policy-templates
    policies = mkOption {
      type = (pkgs.formats.json { }).type;
      description = "Global Policies (passed to equivalent home-manager option)";
    };

    #####

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
          ((concatMapAttrsStringSep "" (k: v: ''
            lockPref(${builtins.toJSON k}, ${builtins.toJSON v});
          '')) cfg.prefs)

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
      };

      programs.firefox = {
        enable = true;

        package = cfg.package.override {
          inherit (cfg) extraPrefs;
        };

        inherit (cfg) policies;

        profiles.default = {
          userChrome =
            let
              inherit (cfg.settings) ui;
              mkHide = x: mkIf (if ui.invert then x else !x);

              displayNone = x: "${x} { display: none !important; }";
              widthZero = x: "${x} { width: 0 !important; }";
            in
            mkMerge [
              (mkHide (ui.pageNext) (displayNone "#forward-button"))
              (mkHide (ui.pagePrev) (displayNone "#back-button"))
              (mkHide (ui.pageReload) (mkMerge [
                (displayNone "#reload-button")
                (displayNone "#stop-button")
              ]))
              (mkHide (ui.tabAll) (displayNone "#alltabs-button"))
              (mkHide (ui.tabClose) (displayNone ".tab-close-button"))
              (mkHide (ui.tabNew) (mkMerge [
                # for some reason there are two???
                (displayNone "#new-tab-button")
                (displayNone "#tabs-newtab-button")
              ]))
              (mkHide (ui.tabNext) (displayNone "#scrollbutton-down"))
              (mkHide (ui.tabPrev) (displayNone "#scrollbutton-up"))
              (mkHide (ui.toolBarSpace) (displayNone "toolbarspring"))
              (mkHide (ui.windowClose) (mkMerge [
                (displayNone ".titlebar-buttonbox-container")
                (widthZero ''.titlebar-spacer[type="post-tabs"]'')
              ]))
            ];
        };
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
        };

        policies = {
          Cookies = {
            Behavior = "reject-foreign";
            Locked = true;
          };

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
