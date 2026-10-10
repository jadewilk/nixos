{ lib, config, ... }:
let
  cfg = config.homelab.routing;
in
{
  imports = lib.filesystem.listFilesRecursive ./service/routing;

  options.homelab.routing = {
    router.enable = lib.mkEnableOption "Router components";
    linkLocal = lib.mkOption {
      type = lib.types.str;
      example = "fe80::...";
      description = ''
        Link local ip address of the router's lan port.
      '';
    };
    ip4 = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.2";
      example = "192.168.0.1";
      description = ''
        The router's ip4 LAN address
      '';
    };
    interfaces = {
      wan = lib.mkOption {
        type = lib.types.str;
        example = "eth1";
        description = ''
          Network to use as the "wan" interface.
        '';
      };
      lan = lib.mkOption {
        type = lib.types.str;
        example = "eth0";
        description = ''
          Network to use as the "lan" interface.
        '';
      };
      uplinks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ cfg.interfaces.wan ];
        description = ''
          Devices that will be used as upstreams for the lan.
          The route metric will be automatically configured in the same order that devices have been passed
        '';
      };
    };
  };
}
