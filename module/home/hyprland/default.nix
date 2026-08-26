{ config, lib, ... }:
let
  inherit (lib) defaultTo elemAt filterAttrs flatten flip mapAttrsToList match mkIf mkLuaInline pipe replaceStrings;

  cfg = config.aquaris.hyprland;

  ##############################################################################

  defaultBinders = standalone: rec {
    lua = mkLuaInline;
    toLua = lib.generators.toLua { };

    dsp = flip pipe [
      (x: "hl.dsp.${x}")
      (x: if standalone then "hl.dispatch(${x})" else x)
      lua
    ];

    function = x: lua "function() ${x} end";
    raw = act: { inherit act; raw = true; };

    exec = cmd: execR cmd { };
    execR = cmd: rules: dsp "exec_cmd(${toLua cmd}, ${toLua rules})";

    focus = args: dsp "focus(${toLua args})";
    move = args: dsp "window.move(${toLua args})";

    fullscreen = internal: client: dsp ''
      window.fullscreen_state({
        action = "toggle",
        internal = ${toString internal},
        client = ${toString client},
      })
    '';
  };

  allBinders = standalone:
    let default = defaultBinders standalone; in
    default // cfg.customBinders default;
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    aquaris.hyprland.settings = {
      env = mapAttrsToList (k: v: { _args = [ k v ]; }) cfg.env;

      bind = pipe cfg.binds [
        (x: x (allBinders false))
        (mapAttrsToList (k: v: pipe k [
          (replaceStrings
            [ "A-" "C-" "S-" ]
            [ "ALT + " "CTRL + " "SHIFT + " ])
          (k: if v.raw then k else "${cfg.mod} + ${k}")
          (k: { _args = [ k v.act ]; })
        ]))
      ];

      on = pipe cfg.events [
        (x: x (allBinders true))
        (mapAttrsToList (k: map (v:
          let
            parts = match "([^ ]+)( .*)?" k;
            event = elemAt parts 0;
            args = defaultTo "" (elemAt parts 1);
          in
          {
            _args = [
              event
              (mkLuaInline "function(${args}) ${v.expr} end")
            ];
          })))
        flatten
      ];

      animation = pipe cfg.animations [
        (x: x (with cfg._util.curveRef.mk; {
          bezier = name: bezier { inherit name; };
          spring = name: spring { inherit name; };
        }))
        (mapAttrsToList (k: v: {
          leaf = k;
          inherit (v) enabled speed style;
          ${v.curve._tag} = v.curve.name;
        }))
        (map (filterAttrs (_: x: x != null)))
      ];

      curve = pipe cfg.curves [
        (x: x cfg._util.curveDef.mk)
        (mapAttrsToList (k: v: {
          _args = [
            k
            (pipe v [
              (x: x // { type = x._tag; })
              (flip removeAttrs [ "_tag" ])
            ])
          ];
        }))
      ];

      window_rule = cfg.windowRules;
      workspace_rule = cfg.workspaceRules;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";

      extraLuaFiles.lib = {
        autoLoad = true;
        content = cfg.precfg;
      };

      inherit (cfg) settings;
    };
  };
}
