{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.flakeConfig.environment.desktop == "sway") {
    # Nixos config
    security.pam.services = {
      greetd.fprintAuth = false;
    };

    environment.systemPackages = with pkgs; [
      xarchiver
    ];

    services = {
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${lib.getExe pkgs.tuigreet} --time --remember --cmd ${lib.getExe pkgs.swayfx}";
          };
        };
      };
      geoclue2 = {
        enable = true;
        enableWifi = true;
        submitData = true;
      };
      gvfs.enable = true;
      udisks2.enable = true;
      logind.settings.Login = {
        powerKey = "poweroff";
        powerKeyLongPress = "reboot";
        lidSwitch = "suspend-then-hibernate";
        lidSwitchExternalPower = "suspend";
      };
    };
    programs.gnome-disks.enable = true;
    programs.dconf.enable = true;

    xdg.portal = {
      config = {
        common = {
          default = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
      enable = true;
      xdgOpenUsePortal = true;
      wlr.enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    };

    # https://github.com/apognu/tuigreet/issues/68#issuecomment-1586359960
    systemd.services.greetd = {
      serviceConfig = {
        Type = "idle";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
      };
      after = [
        "autovt@tty1.service"
      ];
      conflicts = [
        "autovt@tty1.service"
      ];
    };
  };
}
