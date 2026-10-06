{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../osModules/classes/personalDevice
  ];

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    libva-vdpau-driver
    libvdpau-va-gl
  ];
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  environment.systemPackages = with pkgs; [
    marvisclient-linux
  ];

  services.pcscd.enable = true;

  services.thermald.enable = true;

  flakeConfig.environment.primaryHomeManagedUser = "philip";
  home-manager.users."philip".imports = [
    ../../hmModules/programs/sway
    ../../hmModules/guiConfig
    (
      {
        ...
      }:
      {
        home.stateVersion = "24.05";
      }
    )
  ];

  system.stateVersion = "23.05";
}
