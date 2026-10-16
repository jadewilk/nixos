{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.services.ntfy;
  domain = "push.${config.homelab.tld}";
  stateDir = "/var/lib/ntfy-sh";
  credPath = "/run/credentials/ntfy-sh.service";
in
{
  options.homelab.services.ntfy = {
    enable = lib.mkEnableOption "The nfty UnifiedPush server";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.ntfy-envs.file = ../../secrets/ntfy/envs.age;
    age.secrets.ntfy-firebase.file = ../../secrets/ntfy/firebase.age;
    systemd.services.ntfy-sh.serviceConfig = {
      EnvironmentFile = config.age.secrets.ntfy-envs.path;
      LoadCredential = [
        "firebase.json:${config.age.secrets.ntfy-firebase.path}"
      ];
    };

    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${domain}";
        listen-http = "127.0.0.1:2586";
        cache-file = "${stateDir}/cache.db";
        cache-duration = "48h";
        attachment-cache-dir = "${stateDir}/attachments";
        attachment-expiry-duration = "48h";
        attachment-total-size-limit = "10G";
        attachment-file-size-limit = "500M";
        auth-file = "${stateDir}/user.db";
        auth-default-access = "deny-all";
        behind-proxy = true;
        firebase-key-file = "${credPath}/firebase.json";

        # Email config for sending notifs
        smtp-sender-addr = "127.0.0.1:587";
        smtp-sender-user = "ntfy";
        # defined using NTFY_SMTP_SENDER_PASS in the env file
        # smtp-sender-pass = "";
        smtp-sender-from = "push@services.${config.homelab.tld}";
      };
    };

    services.nginx.virtualHosts.${domain}.locations."/" = {
      proxyPass = "http://${config.services.ntfy-sh.settings.listen-http}";
      proxyWebsockets = true;
    };

    networking.domains.subDomains.${domain} = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
    };
  };
}
