{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "git.${config.homelab.tld}";
  sshAddr = ":22";
  httpAddr = ":23433";
in
{
  options.homelab.services.soft-serve.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Whether to enable the soft-serve git server
    '';
  };
  config = lib.mkIf config.homelab.services.soft-serve.enable {
    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://localhost${httpAddr}";
    };

    networking.domains.subDomains.${domain} = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
    };

    networking.firewall.interfaces.${config.homelab.routing.interfaces.lan}.allowedTCPPorts = [ 22 ];

    systemd.services.soft-serve = {
      path = with pkgs; [ openssh ];
      serviceConfig =
        let
          capNet = "CAP_NET_BIND_SERVICE";
        in
        {
          AmbientCapabilities = lib.mkForce capNet;
          CapabilityBoundingSet = lib.mkForce capNet;
          PrivateUsers = lib.mkForce false;
        };
    };

    services.soft-serve = {
      enable = true;
      settings = {
        name = "Jade's repos";
        log_format = "text";
        ssh = {
          listen_addr = sshAddr;
          public_url = "ssh://${domain}${sshAddr}";
          key_path = "ssh/soft_serve_host";
          client_key_path = "ssh/soft_serve_client_ed25519";
          max_timeout = 1200;
          idle_timeout = 600;
        };
        git = {
          listen_addr = ":9418";
          max_timeout = 30;
          idle_timeout = 10;
          max_connections = 32;
        };
        http = {
          listen_addr = httpAddr;
          public_url = "https://${domain}";
        };
        stats.listen_addr = ":23233";
        initial_admin_keys = config.users.users.philip.openssh.authorizedKeys.keys;
      };
    };
  };
}
