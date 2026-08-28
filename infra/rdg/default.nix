{
  config,
  ...
}:
let
  linkNames = config.homelab.routing.interfaces;
  wanMac = "e8:ea:6a:93:e6:1d";
  lanMac = "e8:ea:6a:93:e6:1e";
  primaryWanVlan = "vlan911";
  secondaryWanVlan = "vlan100";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostId = "e9b36049";

  system.stateVersion = "25.11";

  systemd.network.wait-online.enable = false;
  systemd.network.links = {
    "90-${linkNames.wan}" = {
      matchConfig.PermanentMACAddress = wanMac;
      linkConfig = {
        Name = linkNames.wan;
      };
      extraConfig = ''
        [EnergyEfficientEthernet]
        Enable=yes
        TxLowPowerIdle=yes
      '';
    };
    "90-${linkNames.lan}" = {
      matchConfig.PermanentMACAddress = lanMac;
      linkConfig = {
        Name = linkNames.lan;
      };
      extraConfig = ''
        [EnergyEfficientEthernet]
        Enable=yes
        TxLowPowerIdle=yes
      '';
    };
  };

  systemd.network.netdevs = {
    "5-${primaryWanVlan}" = {
      netdevConfig = {
        Kind = "vlan";
        Name = primaryWanVlan;
      };
      vlanConfig.Id = 911;
    };
    "5-${secondaryWanVlan}" = {
      netdevConfig = {
        Kind = "vlan";
        Name = secondaryWanVlan;
      };
      vlanConfig.Id = 100;
    };
  };

  systemd.network.networks = {
    "10-${linkNames.wan}" = {
      matchConfig.PermanentMACAddress = wanMac;
      vlan = [
        primaryWanVlan
      ];
    };
    "15-${linkNames.lan}" = {
      matchConfig.PermanentMACAddress = lanMac;
      vlan = [
        secondaryWanVlan
      ];
      dhcpServerStaticLeases = [
        {
          # brother ql-1110nwb
          Address = "192.168.1.5";
          MACAddress = "BC:F4:D4:98:88:99";
        }
        {
          # miwifi ap
          Address = "192.168.31.16";
          MACAddress = "CC:D8:43:B0:F7:44";
        }
      ];
    };
  };

  networking.domains = {
    enable = true;
    baseDomains.${config.homelab.tld} = { };
    subDomains = {
      ${config.networking.fqdn} = {
        a.data = "158.173.146.38";
        aaaa.data = "2a11:2646:1005:1:eaea:6aff:fe93:e61d";
      };
    };
  };

  homelab = {
    hostname = config.networking.fqdn;
    routing = {
      router.enable = true;
      linkLocal = "fe80::66ab:5898:6981:3273";
      interfaces = {
        wan = "wan";
        lan = "lan";
        uplinks = [
          primaryWanVlan
          secondaryWanVlan
        ];
      };
      systemd.networkd.enableCake = true;
    };
    services.nginx.enable = true;
    services.homeAssistant.enable = true;
  };

  homelab.services.kanidm = {
    enable = true;
    domain = "testing-idm.fogbox.uk";
    backupPath = "/var/lib/kanidm/backups";
  };

  homelab.buildbot.enableWorker = true;
  services.buildbot-nix.worker.masterUrl = "tcp:host=buildbot.fogbox.uk:port=9989";

  homelab.ci.runners.gitlab.csgitlab.enabled = true;
  homelab.ci.runners.gitlab.csgitlab.secretPath = ../../secrets/runners/csgitlab/rdg.age;

  homelab.games.factorio = {
    # Needs statedir option fix /var/lib/factorio
    enable = true;
    admins = [ "wiryfuture" ];
  };

  services.factorio.saveName = "buk2";
}
