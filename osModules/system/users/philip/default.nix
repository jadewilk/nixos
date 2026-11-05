{
  config,
  ...
}:
{
  age.secrets.userPassword.file = ../../../../secrets/workstation_password.age;
  users.users.philip.hashedPasswordFile = config.age.secrets.userPassword.path;

  age.secrets.octodns_desec_secret.file = ../../../../secrets/octodns/desec.age;
  age.identityPaths = [ "/home/philip/.ssh/id_ed25519" ];

  flakeConfig.environment.primaryHomeManagedUser = "philip";
  hjem.users.philip.enable = true;
  hjem.interactive = true;

  users.users.philip = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "adbusers"
      "dialout"
      "libvirtd"
      "video"
      "input"
      "cdrom"
      "optical"
      "plugdev"
      "podman"
      "wireshark"
      "scanner"
      "lp"
      "wpa_supplicant"
    ];
  };
}
