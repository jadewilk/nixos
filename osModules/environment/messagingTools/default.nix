{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    (discord.override { withOpenASAR = true; })
    slack
    teams-for-linux
    signal-desktop
    karere
  ];
}
