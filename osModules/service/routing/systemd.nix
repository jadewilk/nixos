{ config, lib, ... }:
let
  cfg = config.homelab.routing;

  generateUplinkConfiguration = uplinkName: routeMetric: {
    matchConfig.Name = uplinkName;
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = "yes";
      DHCPPrefixDelegation = "yes";
      LinkLocalAddressing = "ipv6";
      IPv4Forwarding = "yes";
    };

    dhcpV4Config = {
      UseHostname = "no";
      UseDNS = "no";
      UseNTP = "no";
      UseSIP = "no";
      UseRoutes = "no";
      UseGateway = "yes";
      RouteMetric = routeMetric;
    };

    ipv6AcceptRAConfig = {
      UseDNS = "no";
      DHCPv6Client = "yes";
      UseGateway = "yes";
      RouteMetric = routeMetric;
    };

    dhcpPrefixDelegationConfig.UplinkInterface = ":self";

    dhcpV6Config = {
      WithoutRA = "solicit";
      UseHostname = "no";
      UseDNS = "no";
      UseNTP = "no";
    };

    cakeConfig = lib.mkIf cfg.systemd.networkd.enableCake {
      Bandwidth = "${cfg.systemd.networkd.cakeBandwidth}M";
      OverheadBytes = 48;
      MPUBytes = 84;
      CompensationMode = "none";
      FlowIsolationMode = "triple";
      PriorityQueueingPreset = "diffserv8";
    };

    linkConfig.RequiredForOnline = "no";
  };

  uplinkInterfaceAttrsList = lib.imap1 (
    i: v: lib.nameValuePair ("10-" + v) (generateUplinkConfiguration v (100 * (i * i)))
  ) cfg.interfaces.uplinks;
  uplinkInterfaceAttrs = builtins.listToAttrs uplinkInterfaceAttrsList;

in
{
  options.homelab.routing.systemd.networkd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.homelab.routing.router.enable;
      example = true;
      description = ''
        Whether to enable systemd network configuration.
      '';
    };
    enableUplinkConfiguration = lib.mkOption {
      type = lib.types.bool;
      default = cfg.systemd.networkd.enable;
      example = false;
      description = ''
        Whether to enable systemd network configuration of the uplink interface.
        Relevant if the uplink interface is being externally managed, eg, by ppp
      '';
    };
    subnet = lib.mkOption {
      type = lib.types.str;
      default = "24";
    };
    ipRange = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/${cfg.systemd.networkd.subnet}";
      example = "192.168.1.0/16";
      description = ''
        IP4 address range to use for the lan
      '';
    };
    enableCake = lib.mkEnableOption "cake qdisc on the wan interface";
    cakeBandwidth = lib.mkOption {
      type = lib.types.str;
      default = "850";
      example = "2250";
      description = ''
        Max bandwidth for CAKE qdisc, in megabits
      '';
    };
  };

  config = lib.mkIf cfg.systemd.networkd.enable {
    networking.useDHCP = false;
    systemd.network = {
      enable = true;
      config.networkConfig.IPv6Forwarding = "yes";
      networks =
        lib.mergeAttrs
          (if (cfg.systemd.networkd.enableUplinkConfiguration) then uplinkInterfaceAttrs else { })
          {
            "15-${cfg.interfaces.lan}" = {
              matchConfig.Name = cfg.interfaces.lan;
              matchConfig.Type = "ether";
              networkConfig = {
                IPv6AcceptRA = "no";
                IPv6SendRA = "yes";
                LinkLocalAddressing = "ipv6";
                DHCPPrefixDelegation = "yes";
                DHCPServer = "yes";
                Address = "${cfg.ip4}/${cfg.systemd.networkd.subnet}";
                IPv4Forwarding = "yes";
                IPMasquerade = "ipv4";
              };

              dhcpServerConfig = {
                EmitRouter = "yes";
                EmitDNS = "yes";
                DNS = cfg.ip4;
                EmitNTP = "yes";
                NTP = cfg.ip4;
                PoolOffset = 100;
                ServerAddress = "${cfg.ip4}/${cfg.systemd.networkd.subnet}";
                UplinkInterface = ":auto";
                DefaultLeaseTimeSec = 1800;
              };

              dhcpServerStaticLeases = [
                # {
                #   # Idac for example
                #   Address = "192.168.1.50";
                #   MACAddress = "54:9f:35:14:57:3e";
                # }
              ];

              linkConfig.RequiredForOnline = "no";

              ipv6SendRAConfig = {
                EmitDNS = "yes";
                DNS = cfg.linkLocal;
                EmitDomains = "no";
              };

              dhcpPrefixDelegationConfig.UplinkInterface = ":auto";
            };
          };
    };

    networking.firewall.logRefusedConnections = lib.mkForce false;

    # Open ports for dhcp server on lan
    networking.firewall.interfaces.${cfg.interfaces.lan}.allowedUDPPorts = [
      67
      68
    ];

    networking.firewall.allowedTCPPorts = [
      80
      443
      636
      389
      25
      465
      993
      22420
      22
      34197
    ];
  };
}
