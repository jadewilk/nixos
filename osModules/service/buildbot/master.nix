{ config, lib, ... }:
let
  domain = "buildbot.${config.homelab.tld}";
in
{
  config = lib.mkIf config.homelab.buildbot.enableMaster {
    age.secrets = {
      workers.file = ../../../secrets/buildbot/workers.age;
      oauth_sec.file = ../../../secrets/buildbot/oauth_sec.age;
      webhook_sec.file = ../../../secrets/buildbot/webhook_sec.age;
      gh_pem.file = ../../../secrets/buildbot/gh_pem.age;
    };

    services.buildbot-master = {
      title = domain;
      titleUrl = "https://${domain}/";
    };

    services.buildbot-nix.master = {
      enable = true;
      domain = domain;

      evalWorkerCount = 4;

      workersFile = config.age.secrets.workers.path;

      admins = [ "jadewilk" ];
      github = {
        appId = 914149;
        appSecretKeyFile = config.age.secrets.gh_pem.path;
        webhookSecretFile = config.age.secrets.webhook_sec.path;
        oauthId = "iv23liss80uhjbjh4cqd";
        oauthSecretFile = config.age.secrets.oauth_sec.path;
        topic = "fogbox-buildbot";
      };
    };

    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      enableACME = true;
    };

    networking.domains.subDomains.${domain} = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
    };
  };
}
