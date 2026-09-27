{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.homelab;
in
{
  imports =
    (builtins.filter (lib.strings.hasSuffix ".nix") (lib.filesystem.listFilesRecursive ./service))
    ++ [
      ./system/idmUserAuth
      ./system/zfs

      ./system/users/philip-server

      ./replaced/services/monitoring/prometheus/exporters.nix
      ./replaced/hardware/sensor/hddtemp.nix
    ];

  options.homelab = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = true;
      description = ''
        Enable the default homelab options:
          - ssh using key access
          - podman enabled
          - prometheus and grafana monitoring
      '';
    };
    isLeader = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Whether this server should act as a host for the key lab services
      '';
    };
    tld = lib.mkOption {
      type = lib.types.str;
      default = null;
      example = "example.com";
      description = ''
        Default top level domain for services.
      '';
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.fqdn;
      example = "sou.uk.regions.fogbox.uk";
      description = ''
        Fqdn hostname of the nixos install.
      '';
    };
    acme.mail = lib.mkOption {
      type = lib.types.str;
      default = null;
      example = "joe.bloggs@example.com";
      description = ''
        Email for acme cert renewals.
      '';
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib";
      example = "/mnt/state";
      description = ''
        Path to store short-term state under
      '';
    };
    archiveDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib";
      example = "/mnt/archive";
      description = ''
        Path to store long-term state under
      '';
    };
    services = {
      grafana = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.homelab.isLeader;
          example = false;
          description = ''
            Whether to enable the homelab grafana instance.
          '';
        };
        domain = lib.mkOption {
          type = lib.types.str;
          default = "grafana.${config.homelab.tld}";
          example = "grafana.example.com";
          description = ''
            Domain for homelab grafana instance.
          '';
        };
      };
      prometheusExporters.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        example = false;
        description = ''
          Whether to enable the homelab prometheus instance.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      # Assertions
      assertions = [
        {
          assertion = config.homelab.services.openldap.enable -> config.homelab.acme.mail != null;
          message = "Openldap requires a cert for ldaps, and acme requires an email to get a cert.";
        }
        {
          assertion = config.homelab.enable -> config.homelab.tld != null;
          message = "Homelab module needs a tld for certs and nginx routing etc.";
        }
      ];
    }
    {
      age.secrets.desec.file = ../secrets/dns/desec.age;
      homelab = {
        tld = "fogbox.uk";
        acme.mail = "philip.wilk10@gmail.com";
      };
    }
    {
      powerManagement.powertop.enable = true;
      powerManagement.cpuFreqGovernor = "powersave";

      networking.domain = "uk.region.fogbox.uk";

      # Accept acme terms
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = config.homelab.acme.mail;
          dnsProvider = "desec";
          dnsResolver = "9.9.9.9:53";
          profile = "shortlived";
          environmentFile = pkgs.writeText "desecEnvs" ''
            DESEC_POLLING_INTERVAL=90
          '';
          credentialFiles = {
            DESEC_TOKEN_FILE = config.age.secrets.desec.path;
          };
        };
      };

      # Enable podman container support
      virtualisation.podman = {
        enable = true;
        dockerSocket.enable = true;
        dockerCompat = true;
      };

      # Fail2ban for ssh
      services.fail2ban = {
        enable = true;
        extraPackages = with pkgs; [ ipset ];
      };

      # Enable ssh access from only workstation ssh keys
      services.openssh = {
        enable = true;
        ports = [ 22420 ];
        listenAddresses = [
          { addr = "0.0.0.0"; }
          { addr = "[::]"; }
        ];
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
      };
    }

    # Grafana
    (lib.mkIf cfg.services.grafana.enable {

      # Grafana and prometheus monithoring
      age.secrets.grafanamail.file = ../secrets/grafana/mail.age;
      age.secrets.grafanaSecret.file = ../secrets/grafana/secret.age;

      systemd.services.grafana.serviceConfig.LoadCredential = [
        "smtpPwd:${config.age.secrets.grafanamail.path}"
        "secretKey:${config.age.secrets.grafanaSecret.path}"
      ];

      age.secrets.prometheusBasicAuthPassword = {
        file = ../secrets/prometheus/basicAuthPassword.age;
        owner = "grafana";
      };

      services = {
        grafana = {
          enable = true;
          dataDir = "${config.homelab.stateDir}/grafana";
          provision = {
            enable = true;
            datasources.settings.datasources = [
              {
                name = "prometheus";
                type = "prometheus";
                isDefault = true;
                url = config.services.prometheus.webExternalUrl;
                access = "proxy";
                basicAuth = true;
                basicAuthUser = "grafana";
                secureJsonData.basicAuthPassword = "$__file{${config.age.secrets.prometheusBasicAuthPassword.path}}";
              }
            ];
          };
          settings = {
            security.secret_key = "$__file(/run/credentials/grafana/secretKey)";
            server = {
              enable_gzip = true;
              enforce_domain = true;
              domain = config.homelab.services.grafana.domain;
              http_addr = "127.0.0.1";
            };
            smtp = {
              user = "grafana";
              startTLS_policy = "NoStartTLS";
              password = "$__file{/run/credentials/grafana.service/smtpPwd}";
              host = "fogbox.uk:465";
              from_address = "grafana@services.fogbox.uk";
              enabled = true;
            };
          };
        };
        # nginx to proxy grafana
        nginx.virtualHosts.${config.homelab.services.grafana.domain} = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
            proxyWebsockets = true;
          };
        };
      };

      networking.domains.subDomains.${config.homelab.services.grafana.domain} = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
    })
    (lib.mkIf cfg.services.prometheusExporters.enable {
      services.dbus.implementation = "broker";

      services.prometheus.exporters = {
        node.enable = true;
        zfs.enable = true;
        smartctl.enable = true;
        unbound = {
          enable = true;
          unbound.host = "unix:///run/unbound/unbound.socket";
        };
        systemd = {
          enable = true;
          extraFlags = [
            "--systemd.collector.enable-restart-count"
            # mia??? https://github.com/prometheus-community/systemd_exporter/issues/177
            # "--systemd.collector.enable-file-descriptor-size"
            "--systemd.collector.enable-ip-accounting"
          ];
        };
      };

      age.secrets.nodeHtpasswd = {
        file = ../secrets/prometheus/exporters/node/htpasswd.age;
        owner = "nginx";
      };
      age.secrets.zfsHtpasswd = {
        file = ../secrets/prometheus/exporters/zfs/htpasswd.age;
        owner = "nginx";
      };
      age.secrets.smartctlHtpasswd = {
        file = ../secrets/prometheus/exporters/smartctl/htpasswd.age;
        owner = "nginx";
      };
      age.secrets.systemdHtpasswd = {
        file = ../secrets/prometheus/exporters/systemd/htpasswd.age;
        owner = "nginx";
      };
      age.secrets.unboundHtpasswd = {
        file = ../secrets/prometheus/exporters/unbound/htpasswd.age;
        owner = "nginx";
      };
      services.nginx.virtualHosts = {
        "n.stats.${cfg.hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.node.port}";
            proxyWebsockets = true;
            basicAuthFile = config.age.secrets.nodeHtpasswd.path;
          };
        };
        "z.stats.${cfg.hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}";
            proxyWebsockets = true;
            basicAuthFile = config.age.secrets.zfsHtpasswd.path;
          };
        };
        "smart.stats.${cfg.hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}";
            proxyWebsockets = true;
            basicAuthFile = config.age.secrets.smartctlHtpasswd.path;
          };
        };
        "systemd.stats.${cfg.hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.systemd.port}";
            proxyWebsockets = true;
            basicAuthFile = config.age.secrets.systemdHtpasswd.path;
          };
        };
        "unbound.stats.${cfg.hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.unbound.port}";
            proxyWebsockets = true;
            basicAuthFile = config.age.secrets.unboundHtpasswd.path;
          };
        };
      };
      networking.domains.subDomains."*.stats.${config.networking.fqdn}" = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
    })
    (lib.mkIf (cfg.isLeader) {
      age.secrets.nodeBasicAuthPassword = {
        file = ../secrets/prometheus/exporters/node/basicAuthPassword.age;
        owner = "prometheus";
      };
      age.secrets.zfsBasicAuthPassword = {
        file = ../secrets/prometheus/exporters/zfs/basicAuthPassword.age;
        owner = "prometheus";
      };
      age.secrets.smartctlBasicAuthPassword = {
        file = ../secrets/prometheus/exporters/smartctl/basicAuthPassword.age;
        owner = "prometheus";
      };
      age.secrets.nutBasicAuthPassword = {
        file = ../secrets/prometheus/exporters/nut/basicAuthPassword.age;
        owner = "prometheus";
      };
      age.secrets.systemdBasicAuthPassword = {
        file = ../secrets/prometheus/exporters/systemd/basicAuthPassword.age;
        owner = "prometheus";
      };
      age.secrets.unboundBasicAuthPassword = {
        file = ../secrets/prometheus/exporters/unbound/basicAuthPassword.age;
        owner = "prometheus";
      };
      services.prometheus =
        let
          genStatNames = hostnames: suff: map (hostname: "${suff}.stats.${hostname}") hostnames;
          targetHostnames = [
            "sou.uk.region.${cfg.tld}"
            "rdg.uk.region.${cfg.tld}"
          ];
        in
        {
          enable = true;
          enableReload = true;
          webExternalUrl = "https://prometheus.${cfg.tld}/";
          scrapeConfigs = [
            {
              job_name = "node";
              scheme = "https";
              basic_auth = {
                username = "prometheus";
                password_file = config.age.secrets.nodeBasicAuthPassword.path;
              };
              static_configs = [
                {
                  targets = genStatNames targetHostnames "n";
                }
              ];
            }
            {
              job_name = "zfs";
              scheme = "https";
              basic_auth = {
                username = "prometheus";
                password_file = config.age.secrets.zfsBasicAuthPassword.path;
              };
              static_configs = [
                {
                  targets = genStatNames targetHostnames "z";
                }
              ];
            }
            {
              job_name = "smartctl";
              scheme = "https";
              basic_auth = {
                username = "prometheus";
                password_file = config.age.secrets.smartctlBasicAuthPassword.path;
              };
              static_configs = [
                {
                  targets = genStatNames targetHostnames "smart";
                }
              ];
            }
            {
              job_name = "systemd";
              scheme = "https";
              basic_auth = {
                username = "prometheus";
                password_file = config.age.secrets.systemdBasicAuthPassword.path;
              };
              static_configs = [
                {
                  targets = genStatNames targetHostnames "systemd";
                }
              ];
            }
            {
              job_name = "nut";
              metrics_path = "/ups_metrics";
              params = {
                ups = [ "SMT1500I" ];
              };
              basic_auth = {
                username = "prometheus";
                password_file = config.age.secrets.nutBasicAuthPassword.path;
              };
              static_configs = [
                {
                  targets = [
                    "nut.stats.sou.uk.region.fogbox.uk"
                  ];
                  labels = {
                    ups = "SMT1500I";
                  };
                }
              ];
            }
            {
              job_name = "unbound";
              scheme = "https";
              basic_auth = {
                username = "prometheus";
                password_file = config.age.secrets.unboundBasicAuthPassword.path;
              };
              static_configs = [
                {
                  targets = genStatNames targetHostnames "unbound";
                }
              ];
            }
          ];
        };

      age.secrets.prometheusBasicAuth = {
        file = ../secrets/prometheus/htpasswd.age;
        owner = "nginx";
      };

      services.nginx.virtualHosts."prometheus.${cfg.tld}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.prometheus.port}";
          proxyWebsockets = true;
          basicAuthFile = config.age.secrets.prometheusBasicAuth.path;
        };
      };

      networking.domains.subDomains."prometheus.${cfg.tld}" = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };

    })
    # Zfs monitoring
    (lib.mkIf config.boot.zfs.enabled {
      age.secrets.zedPwd.file = ../secrets/msmtp/zedPwd.age;
      systemd.services.zfs-zed.serviceConfig.LoadCredential = [
        "smtpPwd:${config.age.secrets.zedPwd.path}"
      ];

      programs.msmtp = {
        enable = true;
        setSendmail = true;
        defaults = {
          aliases = "/etc/aliases";
          port = 465;
          tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
          tls = "on";
          auth = "login";
          tls_starttls = "off";
        };
        accounts = {
          default = {
            host = "${cfg.tld}";
            passwordeval = "cat /run/credentials/zfs-zed.service/smtpPwd";
            user = "zfs";
            from = "zfs@services.${cfg.tld}";
          };
        };
      };

      services.zfs = {
        zed = {
          settings = {
            ZED_EMAIL_ADDR = [ "philipwilk@fogbox.uk" ];
            ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
            ZED_EMAIL_OPTS = "@ADDRESS@";

            ZED_NOTIFY_INTERVAL_SECS = 360;
            ZED_NOTIFY_VERBOSE = true;

            ZED_USE_ENCLOSURE_LEDS = true;
            ZED_SCRUB_AFTER_RESILVER = true;
          };
          enableMail = false;
        };
      };
    })
    {
      services.mysql.dataDir = "${config.homelab.stateDir}/mysql";
      services.postgresql.dataDir = "${config.homelab.stateDir}/postgresql/${config.services.postgresql.package.psqlSchema}";
      services.postgresql.package = pkgs.postgresql_18;
    }
  ];
}
