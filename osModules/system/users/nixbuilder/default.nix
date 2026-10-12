{
  ...
}:
{
  users.users.nixbuilder.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK54JexRvmPyj6ikWNSDCzqyJD7zzFF1w2G0lYeXWFUz root@probook"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIByxL7YIIXda/uEO6UFBuRzgdwQukzOcUEzhcTdLgGya root@prime"
  ];
  users.users.nixbuilder = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    createHome = true;
    homeMode = "700";
  };

  nix.settings.trusted-users = [ "nixbuilder" ];
}
