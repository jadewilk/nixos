{
  lib,
  pkgs,
  config,
  ...
}:
{

  config = lib.mkIf (config.flakeConfig.environment.desktop == "gamescope") {
    boot = {
      kernelParams = [
        "quiet"
        "splash"
        "console=/dev/null"
      ];
      plymouth.enable = true;
    };

    environment.systemPackages = with pkgs; [
      gamescope
      gamescope-wsi # HDR won't work without this
    ];

    programs = {
      gamescope = {
        enable = true;
        enableWsi = true;
        capSysNice = true;
      };
      steam.gamescopeSession.enable = true;
    };

    services = {
      libinput.mouse.accelProfile = "flat";
      xserver.enable = false;
      getty.autologinUser = "philip";
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.gamescope}/bin/gamescope -W 1920 -H 1080 -f -e --xwayland-count 2 --hdr-enabled --hdr-itm-enabled -- steam -pipewire-dmabuf -gamepadui -steamdeck -steamos3 > /dev/null 2>&1";
            user = "philip";
          };
        };
      };
    };
  };
}
