{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.routing;

  dnsDomains = builtins.attrNames config.networking.domains.subDomains;
  simpleDataDomains = map (lib.removePrefix "*.") dnsDomains;
  getLocalV4 = map (host: "\"${host}. 3600 IN A ${cfg.ip4}\"");
  localData4 = getLocalV4 simpleDataDomains;
  localData6 = map (host: "\"${host}. 3600 IN AAAA ${cfg.linkLocal}\"") simpleDataDomains;
  additionalLocal4 = getLocalV4 config.homelab.dns.additionalLocalRecords;
  localData = localData4 ++ additionalLocal4 ++ localData6;

  wildcardRecords = builtins.filter (lib.hasPrefix "*.") dnsDomains;
  localZoneDomains = map (lib.removePrefix "*.") wildcardRecords;
  localZone = map (host: "\"${host}\" redirect") localZoneDomains;
in
{
  options.homelab.dns.additionalLocalRecords = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config = lib.mkIf config.homelab.routing.router.enable {
    networking.firewall.interfaces.${cfg.interfaces.lan} = {
      allowedTCPPorts = [
        53
        9153
        config.services.adguardhome.port
      ];
      allowedUDPPorts = [
        53
      ];
    };

    # Since we manage links using networkd, need to force disable resolved so 127.0.0.53 is free
    services.resolved.enable = lib.mkForce false;

    services.redis.servers.unbound = {
      enable = true;
      port = 6399;
    };

    services.unbound = {
      enable = true;
      package = pkgs.unbound.override {
        withRedis = true;
        withSystemd = true;
      };
      settings = {
        server = {
          verbosity = 1;
          extended-statistics = true;
          interface = [
            "0.0.0.0"
            "::0"
          ];
          port = 5300;
          access-control = [
            "127.0.0.1 allow"
            "::1 allow"
            "${config.homelab.routing.systemd.networkd.ipRange} allow"
            "fe80::/64 allow"
            "fd00::/8 allow"
            "2000::/3 allow"
          ];
          prefetch = true;
          prefetch-key = true;
          edns-buffer-size = 1232;
          module-config = "\"validator cachedb iterator\"";
          do-not-query-localhost = false;
          hide-identity = true;
          hide-version = true;
          prefer-ip6 = true;
          num-threads = 4;
          so-reuseport = true;
          rrset-cache-size = "512m";
          msg-cache-size = "256m";
          key-cache-size = "256m";
          neg-cache-size = "256m";

          private-address = [
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "169.254.0.0/16"
            "fd00::/8"
            "fe80::/10"
          ];
          local-zone = localZone;
          local-data = localData;
        };
        remote-control = {
          control-enable = true;
          control-interface = "/run/unbound/unbound.socket";
        };
        cachedb = {
          backend = "\"redis\"";
          redis-server-host = "127.0.0.1";
          redis-server-port = config.services.redis.servers.unbound.port;
          redis-expire-records = true;
        };
      };
    };
    services.adguardhome = {
      enable = true;
      port = 5353;
      host = cfg.ip4;
      mutableSettings = false;
      settings = {
        dns =
          let
            port = builtins.toString config.services.unbound.settings.server.port;
            local = [
              "[::1]:${port}"
              "127.0.0.1:${port}"
            ];

          in
          {
            bootstrap_dns = local;
            bootstrap_prefer_ipv6 = true;
            upstream_dns = local;
            upstream_mode = "parallel";
            enable_dnssec = false;
            serve_http3 = true;
            hostsfile_enabled = false;
            bind_hosts = [
              "127.0.0.1"
              "::1"
              cfg.ip4
            ];
            cache_enabled = false;
          };

        statistics.enabled = true;

        filtering = {
          protection_enabled = true;
          filtering_enabled = true;

          safe_search = {
            enabled = false;
          };
        };

        filters = (
          map
            (url: {
              enabled = true;
              url = url;
            })
            [
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt" # Ads
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt" # The Big List of Hacked Malware Web Sites
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt" # malicious url blocklist
            ]
        );
      };
    };
  };
}
