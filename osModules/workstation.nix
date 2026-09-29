{
  ...
}:
{
  imports = [
    # original modules
    ./system/lanzaboote
    ./system/iwd
    ./system/deepSleep
    ./system/plymouth
    ./system/wayland
    ./system/networkManagerResolved
    ./system/sound
    ./system/bluetooth
    ./system/security
    ./system/powerProfiles
    ./system/timezoned

    ./environment/containers
    ./environment/virtualisation
    ./environment/androidTools
    ./environment/dbTools
    ./environment/nixTools
    ./environment/mediaTools
    ./environment/mediaEditingTools
    ./environment/mediaAuthoringTools
    ./environment/flashingSerialTools
    ./environment/devTools
    ./environment/fileSyncTools
    ./environment/ime
    ./environment/printingScanning
    ./environment/fonts
    ./environment/desktopTools
    ./environment/messagingTools
    ./environment/writingReadingTools
    ./environment/fonts

    ./environment/programs/kanidm
    ./environment/programs/openssh
    ./environment/programs/gnomeKeyring
    ./environment/programs/flatpak

    # replaced modules
    # ./replaced/path/to/module.nix
  ];
}
