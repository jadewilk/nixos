{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.services.kanidm;
in
{
  options.homelab.services.kanidm = {
    enable = lib.mkEnableOption "The kanidm idm server";
    domain = lib.mkOption {
      description = "domain for the kanidm server";
      example = "idm.example.com";
      type = lib.types.str;
      default = "idm.${config.homelab.tld}";
    };
    backupPath = lib.mkOption {
      description = "path for kanidm backups.";
      example = "/mnt/kanidm";
      type = lib.types.str;
    };
    backupCount = lib.mkOption {
      description = "number of kanidm backups to keep. 0 to disable backups";
      type = lib.types.int;
      default = 5;
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "https://${config.services.kanidm.server.settings.bindaddress}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_session_reuse off;
          proxy_set_header X_FORWARDED_PROTO https;
        '';
      };
    };

    networking.domains.subDomains.${cfg.domain} = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
    };

    systemd.services.kanidm = {
      wants = [ "acme-${cfg.domain}.service" ];
      after = [ "acme-${cfg.domain}.service" ];
      serviceConfig = {
        LoadCredential = [
          "key.pem:${config.security.acme.certs.${cfg.domain}.directory}/key.pem"
          "full.pem:${config.security.acme.certs.${cfg.domain}.directory}/full.pem"
        ];
      };
    };

    # Open ldaps port
    networking.firewall.allowedTCPPorts = [ 636 ];

    services.kanidm = {
      package = pkgs.kanidm_1_11;
      client.enable = true;
      client.settings.uri = config.services.kanidm.server.settings.origin;
      server.enable = true;
      server.settings = {
        version = "2";
        db_fs_type = "zfs";
        #db_path = lib.mkForce "${config.homelab.stateDir}/kanidm/kanidm.db"; # why is this read only you state heathens
        domain = cfg.domain;
        origin = "https://${cfg.domain}";
        bindaddress = "[::]:8991";
        http_client_address_info.x-forward-for = [ "127.0.0.1" ];
        ldapbindaddress = "[::]:636";
        online_backup = {
          path = cfg.backupPath;
          versions = cfg.backupCount;
        };

        tls_key = "/run/credentials/kanidm.service/key.pem";
        tls_chain = "/run/credentials/kanidm.service/full.pem";
      };
    };
  };
}
