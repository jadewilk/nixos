let
  pc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMJEglhv4CBSjHclGcDmolVViPXFIqv9o7yTJwYaULP philip@nixowos";
  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBv5FgfTO1OENN87FnrI3G+Sc/TNoYvOubZUXhEQrYAe philip@nixowos-laptop";
  workstations = [
    pc
    laptop
  ];

  sou = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGygqcot7EsJMlGPMFiiKE6GruHaxUPwsJqBH1HiykOG root@itxserve";
  rdg = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO3B4pG0Ztyg+D2FFt69oRRcNLWCdy79oMlQ3pjATbZ5 root@rdg";
  servers = [
    sou
    rdg
  ];

  s = x: "secrets/${x}.age";
in
{
  # wifi passwords
  ${s "wifiPasswords"}.publicKeys = servers ++ workstations;
  #
  ${s "dns/desec"}.publicKeys = servers;
  ${s "ldap_admin_pw"}.publicKeys = servers ++ workstations;
  ${s "server_password"}.publicKeys = servers ++ workstations;
  ${s "workstation_password"}.publicKeys = workstations;
  ${s "nextcloud_admin"}.publicKeys = servers ++ workstations;
  ${s "nextcloud_sql"}.publicKeys = servers;
  ${s "factorio_password"}.publicKeys = servers ++ workstations;
  # mediawiki
  ${s "mediawiki/password"}.publicKeys = servers;
  ${s "mediawiki/gh"}.publicKeys = servers;
  ${s "mediawiki/gl"}.publicKeys = servers;
  ${s "mail_ldap"}.publicKeys = servers;
  ${s "atm8"}.publicKeys = servers ++ workstations;
  ${s "mail_admin"}.publicKeys = servers;
  ${s "mail_pwd"}.publicKeys = servers;
  # Harmonia nix cache
  ${s "harmonia"}.publicKeys = servers;
  # Mail server
  ${s "mail/fogbox.uk-rsa"}.publicKeys = servers;
  ${s "mail/fogbox.uk-ed25519"}.publicKeys = servers;
  ${s "mail/services.fogbox.uk-rsa"}.publicKeys = servers;
  ${s "mail/services.fogbox.uk-ed25519"}.publicKeys = servers;
  # Vaultwarden
  ${s "vaultwarden_smtp"}.publicKeys = servers;
  # Grafana
  ${s "grafana/mail"}.publicKeys = servers;
  ${s "grafana/secret"}.publicKeys = servers;
  # Prometheus
  ${s "prometheus/htpasswd"}.publicKeys = servers;
  ${s "prometheus/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/node/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/node/htpasswd"}.publicKeys = servers;
  ${s "prometheus/exporters/zfs/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/zfs/htpasswd"}.publicKeys = servers;
  ${s "prometheus/exporters/smartctl/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/smartctl/htpasswd"}.publicKeys = servers;
  ${s "prometheus/exporters/nut/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/nut/htpasswd"}.publicKeys = servers;
  ${s "prometheus/exporters/systemd/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/systemd/htpasswd"}.publicKeys = servers;
  ${s "prometheus/exporters/unbound/basicAuthPassword"}.publicKeys = servers;
  ${s "prometheus/exporters/unbound/htpasswd"}.publicKeys = servers;
  # Mastodon
  ${s "mastodon/smtp"}.publicKeys = servers;
  ${s "mastodon/pub"}.publicKeys = servers;
  ${s "mastodon/priv"}.publicKeys = servers;
  ${s "mastodon/otpSec"}.publicKeys = servers;
  ${s "mastodon/secBase"}.publicKeys = servers;
  # forgejo
  ${s "forgejo/smtp"}.publicKeys = servers;
  ${s "forgejo/runner_tok"}.publicKeys = servers;
  ${s "searxng/sec"}.publicKeys = servers;
  # msmtp passwords
  ${s "msmtp/zedPwd"}.publicKeys = servers;
  # Wireguard
  ${s "wireguard/itxserve/private"}.publicKeys = [ sou ];
  ${s "wireguard/probook/private"}.publicKeys = [ laptop ];
  ${s "wireguard/prime/private"}.publicKeys = [ pc ];
  # Jupyterhub
  ${s "jupyter-envs"}.publicKeys = servers;
  #  gitlab-runner
  ${s "runners/csgitlab/sou"}.publicKeys = [ sou ];
  ${s "runners/csgitlab/rdg"}.publicKeys = [ rdg ];
  # upsmon user
  ${s "upsmon/sou"}.publicKeys = servers;
  # ntfy-sh envs
  ${s "ntfy/envs"}.publicKeys = servers;
  ${s "ntfy/firebase"}.publicKeys = servers;
  # Mollysocket vapid file
  ${s "mollysocket-vapid"}.publicKeys = servers;
  # olilo pppoe
  ${s "pppoe-chap"}.publicKeys = servers;
  # mosquitto MQTT server
  ${s "mosquitto/zigbeeMqttPwd"}.publicKeys = servers;
  ${s "mosquitto/homeassistantMqttPwd"}.publicKeys = servers;
  ${s "mosquitto/zigbeeMqttPwdYml"}.publicKeys = servers;
  # octodns
  ${s "octodns/desec"}.publicKeys = workstations;

  # work vpn config
  ${s "openvpn/work/config"}.publicKeys = workstations;
  ${s "openvpn/work/creds"}.publicKeys = workstations;

  # oauth2-proxy
  ${s "oauth2proxy/client"}.publicKeys = servers;
  ${s "oauth2proxy/cookieSecret"}.publicKeys = servers;
}
