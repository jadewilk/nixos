{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    dbeaver-bin
    openldap
    apache-directory-studio
    redisinsight
  ];
}
