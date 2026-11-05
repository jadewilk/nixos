{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkMerge [
    {
      networking.networkmanager.wifi.backend = lib.mkDefault "iwd";

      environment.systemPackages = with pkgs; [
        iw
      ];

      specialisation.wpaSupplicant.configuration = {
        networking.networkmanager.wifi.backend = lib.mkForce "wpa_supplicant";
        networking.wireless = {
          enable = true;
          allowAuxiliaryImperativeNetworks = true;
        };
      };
    }

    (lib.mkIf (config.networking.networkmanager.wifi.backend == "iwd") {
      environment.systemPackages = with pkgs; [
        impala
        iwmenu
      ];
      networking.wireless.iwd = {
        enable = lib.mkDefault true;
        settings = {
          General = {
            UseDefaultNetwork = true;
            AddressRandomization = "network";
          };
          Network = {
            EnableIPv6 = true;
            RoutePriorityOffset = 300;
            NameResolvingService = "systemd";
          };
          Settings = {
            AutoConnect = true;
          };
          Scan = {
            DisablePeriodicScan = true;
          };
        };
      };

      systemd.services.iwd.serviceConfig.ExecStartPre =
        let
          sleep = lib.getExe' pkgs.uutils-coreutils "uutils-sleep";
        in
        [
          "${sleep} 2s"
        ];

      boot.kernelModules = [
        "pkcs8_key_parser"
      ];

    })
  ];
}
