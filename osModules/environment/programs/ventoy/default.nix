{
  pkgs,
  ...
}:
{
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.17"
  ];

  environment.systemPackages = with pkgs; [
    ventoy-full
  ];
}
