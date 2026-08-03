{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../system/users/philip

    ../../system/drivers/opentablet
    ../../system/drivers/openrazer

    ../../environment/programs/ventoy
    ../../environment/programs/matlab
    ../../environment/programs/arion
    ../../environment/programs/openvpn
    ../../environment/programs/kitty
    ../../environment/programs/steam
    ../../environment/programs/octodns
    ../../environment/programs/lego
    ../../environment/programs/winbox
    ../../environment/programs/mullvad
    ../../environment/programs/intellij

    ../../environment/arrrTools
    ../../environment/gameLaunchers

    ../../environment/windowsRebootAlias
  ];

  flakeConfig.environment.desktop = "sway";

  specialisation.withGnome.configuration = {
    flakeConfig.environment.desktop = lib.mkForce "gnome";
  };
  specialisation.withGamescope.configuration = {
    flakeConfig.environment.desktop = lib.mkForce "gamescope";
  };

  boot.kernelParams = [ "net.ipv4.tcp_mtu_probing=1" ];
  boot.kernelModules = [ "sg" ];
  boot.plymouth = {
    themePackages = with pkgs; [ plymouth-blahaj-theme ];
    theme = "blahaj";
  };

  powerManagement.enable = true;
}
