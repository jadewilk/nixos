{
  config,
  lib,
  pkgs,
  ...
}:
let
  catppuccin = builtins.readFile (
    pkgs.catppuccin.override {
      accent = "rosewater";
      variant = "latte";
    }
    + "/waybar/latte.css"
  );
  waybar-style = builtins.readFile ./waybar.css;
in
{
  home.packages = with pkgs; [
    # Desktop chore replacements
    loupe
    nautilus
    gcr
    seahorse
    wmname

    bluetuith

    swaynotificationcenter
    brightnessctl
    pamixer
    gnused
    wdisplays
    # SOME SILLY DEVS USE THE GNOME SPECIFIC ICONS INSTEAD OF LIBADWAITA THANKS <3 <3 <3
    adwaita-icon-theme
    # Appindicator
    libappindicator
    libappindicator-gtk3

    awww
  ];

  # Home manager config
  home.sessionVariables = {
    "_JAVA_AWT_WM_NONREPARENTING" = "1";
  };

  programs = {
    waybar = {
      enable = true;
      systemd = {
        enable = true;
        targets = [ "sway-session.target" ];
      };
      settings.mainbar = {
        layer = "top";
        modules-left = [
          "sway/workspaces"
          "sway/mode"
          "sway/window"
        ];
        "sway/workspaces" = {
          format = "{icon} {name}";
          format-icons = {
            default = "";
            focused = "󰍹";
          };
        };
        "sway/window" = {
          format = "󰘔 {app_id}";
        };
        modules-center = [
          "clock"
          "mpris"
        ];
        clock = {
          interval = 1;
          format = "{:%Y-%m-%d %H:%M:%S}";
        };
        mpris = {
          format = "{player_icon} {player}: {artist} {title}";
        };
        modules-right = [
          "tray"
          "custom/wdisplays"
          "bluetooth"
          "network"
          "backlight"
          "wireplumber"
          "battery"
        ];
        tray = {
          spacing = 4;
        };
        "custom/wdisplays" = {
          format = "󰍹";
          on-click = "wdisplays";
        };
        bluetooth = {
          format-on = "󰂯";
          format-off = "󰂲";
          format-disabled = "󰂲";
          format-connected = "󰂱 {status}";
          format-connected-battery = "󰂱 {status} at 󰥉 {device_battery_percentage}%";
          on-click = "kitty bluetuith";
        };
        network = {
          format-ethernet = "󰈀 {ipaddr}";
          format-wifi = "{icon} {essid}";
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          format-disconnected = "󰤮 Disconnected";
          on-click = "kitty nmtui";
        };
        backlight = {
          format = "{icon} {percent}%";
          format-icons = [
            "󰃚"
            "󰃛"
            "󰃜"
            "󰃝"
            "󰃞"
            "󰃟"
            "󰃠"
          ];
        };
        wireplumber = {
          format = "{icon} {volume}%";
          format-icons = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          format-muted = "󰸈 0%";
          on-click = "pavucontrol";
        };
        battery = {
          format = "{icon} {time} at {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          format-time = "{H}hrs {M}min remaining";
        };
      };
      style = catppuccin + waybar-style;
    };
    xplr.enable = true;
  };

  services = {
    avizo.enable = true;
    playerctld.enable = true;
    wlsunset = {
      enable = true;
      latitude = "51.4";
      longitude = "-0.9";
      temperature = {
        day = 6500;
        night = 3700;
      };
    };
    gnome-keyring = {
      enable = true;
      components = [
        "pkcs11"
        "secrets"
        "ssh"
      ];
    };
  };

  xdg.userDirs.createDirectories = true;

  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.swayfx;
    systemd.xdgAutostart = true;
    swaynag.enable = true;
    wrapperFeatures = {
      base = true;
      gtk = true;
    };
    checkConfig = false;
    config = {
      defaultWorkspace = "workspace number 1";
      modifier = "Mod4";
      terminal = "kitty";
      # ugly, but this fixes most issues, until home-manager adopts environment.d
      startup = [
        { command = "systemctl --user import-environment"; }
      ];

      input = {
        "type:keyboard" = {
          xkb_layout = "gb";
          xkb_variant = "colemak";
          xkb_numlock = "enabled";
        };
        "type:pointer" = {
          accel_profile = "flat";
          natural_scroll = "enabled";
        };
        "type:touchpad" = {
          accel_profile = "flat";
          natural_scroll = "enabled";
          tap = "enabled";
          tap_button_map = "lrm";
        };
      };

      bars = [ ];

      window = {
        border = 0;
        hideEdgeBorders = "smart";
      };
      gaps = {
        inner = 8;
      };

      colors = {
        focused = {
          background = "#dc8a78";
          border = "#dc8a78";
          text = "#6c6f85";
          indicator = "#e6e9ef";
          childBorder = "#e6e9ef";
        };
        unfocused = {
          background = "#fff0f5";
          border = "#fff0f5";
          text = "#4c4f69";
          indicator = "#dc8a78";
          childBorder = "#dc8a78";
        };
      };

      menu = "${lib.getExe pkgs.fuzzel}";

      output = {
        DP-3 = {
          mode = "3440x1440@144.000Hz";
          adaptive_sync = "on";
        };
      };

      keybindings =
        let
          mod = config.wayland.windowManager.sway.config.modifier;

          #pamixer = lib.getExe pkgs.pamixer;
          #brightnessctl = lib.getExe pkgs.brightnessctl;
          playerctl = lib.getExe pkgs.playerctl;
          grim = lib.getExe pkgs.grim;
          slurp = lib.getExe pkgs.slurp;
        in
        lib.mkOptionDefault {
          # terminal
          "${mod}+t" = "exec ${config.wayland.windowManager.sway.config.terminal}";
          # Volume
          "XF86AudioMute" = "exec volumectl toggle-mute";
          "XF86AudioRaiseVolume" = "exec volumectl -u up";
          "XF86AudioLowerVolume" = "exec volumectl -u down";
          # Brightness
          "XF86MonBrightnessDown" = "exec lightctl down";
          "XF86MonBrightnessUp" = "exec lightctl up";
          # Media keys
          "XF86AudioStop" = "exec ${playerctl} stop";
          "XF86AudioPlay" = "exec ${playerctl} play-pause";
          "XF86AudioPause" = "exec ${playerctl} play-pause";
          "XF86AudioNext" = "exec ${playerctl} next";
          "XF86AudioPrev" = "exec ${playerctl} previous";
          # Screenshots
          "Print" =
            ''exec ${grim} -g "$(${slurp} -d)" - | wl-copy -t image/png && wl-paste > ~/Pictures/Screenshots/screenshot-$(date).png'';
        };
    };
    # Swayfx
    extraConfig = ''
      corner_radius 8
      titlebar_separator disable
      titlebar_border_thickness 0
      shadows enable

      bindgesture swipe:right workspace prev
      bindgesture swipe:left workspace next

      exec ${lib.getExe' pkgs.udiskie "udiskie"}

      exec swaync
      bindsym Mod4+Shift+n exec swaync-client -t -sw

      exec ${lib.getExe' pkgs.awww "awww-daemon"}
    '';
  };
}
