{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    picard
    asunder
    makemkv
    mkvtoolnix
  ];
}
