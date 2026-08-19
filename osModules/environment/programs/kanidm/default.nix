{
  pkgs,
  ...
}:
{
  services.kanidm = {
    client.enable = true;
    package = pkgs.kanidm_1_11;
    client.settings.uri = "https://testing-idm.fogbox.uk";
  };
}
