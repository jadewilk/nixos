{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.homelab.services.homeAssistant.enable = lib.mkEnableOption "the home assistant config";

  # starting from https://wiki.nixos.org/wiki/Home_Assistant#Native_installation
  config = lib.mkIf config.homelab.services.homeAssistant.enable {
    services.home-assistant = {
      enable = true;
      extraComponents = [
        # Components required to complete the onboarding
        "analytics"
        "google_translate"
        "met"
        "shopping_list"
        # Recommended for fast zlib compression
        # https://www.home-assistant.io/integrations/isal
        "isal"
        # stuff
        "nanoleaf"
        "cast"
        "denonavr"
        "heos"
        "androidtv_remote"
        "thread"
        "matter"
        "otbr"
        "mqtt"
        "zeroconf"
      ];
      config = {
        # Includes dependencies for a basic setup
        # https://www.home-assistant.io/integrations/default_config/
        default_config = { };

        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";

        # to use postgres
        recorder.db_url = "postgresql://@/hass";
      };
      extraPackages = ps: with ps; [ psycopg2 ];
    };

    # mosquitto is the mqtt server, zigbee2mqtt deals with the dongle
    age.secrets.zigbeeMqttPwd = {
      file = ../../secrets/mosquitto/zigbeeMqttPwd.age;
    };
    age.secrets.homeassistantMqttPwd = {
      file = ../../secrets/mosquitto/homeassistantMqttPwd.age;
    };
    age.secrets.zigbeeMqttPwdYml = {
      file = ../../secrets/mosquitto/zigbeeMqttPwdYml.age;
    };
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          users = {
            zigbee2mqtt = {
              passwordFile = config.age.secrets.zigbeeMqttPwd.path;
              acl = [
                "read zigbee2mqtt/#"
                "write zigbee2mqtt/#"
                "read homeassistant/#"
                "write homeassistant/#"
              ];
            };
            hazigbee = {
              passwordFile = config.age.secrets.homeassistantMqttPwd.path;
              acl = [
                "read zigbee2mqtt/#"
                "write zigbee2mqtt/#"
                "read homeassistant/#"
                "write homeassistant/#"
              ];
            };
          };
        }
      ];
    };
    systemd.services.zigbee2mqtt.serviceConfig = {
      LoadCredential = [
        "mqttPwd.yaml:${config.age.secrets.zigbeeMqttPwdYml.path}"
      ];
      Restart = lib.mkForce "always";
      StandardError = "inherit";
      StandardOutput = "inherit";
    };

    services.zigbee2mqtt = {
      enable = true;
      settings = {
        homeassistant = {
          enabled = config.services.home-assistant.enable;
          discover_topic = "homeassistant";
          status_topic = "homeassistant/status";
        };
        serial = {
          port = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_2086ce948b38ef11b625317af3d9b1e5-if00-port0";
          adapter = "ember";
        };
        frontend = {
          enable = true;
          port = 8888;
        };
        mqtt = {
          server = "mqtt://localhost:1883";
          version = 5;
          user = "zigbee2mqtt";
          password = "!/run/credentials/zigbee2mqtt.service/mqttPwd.yaml password";
        };
        advanced.log_level = "warning";
      };
    };

    networking.firewall.interfaces.${config.homelab.routing.interfaces.lan}.allowedTCPPorts = [
      config.services.openthread-border-router.rest.listenPort
      config.services.openthread-border-router.web.listenPort
      config.services.zigbee2mqtt.settings.frontend.port
      config.services.matter-server.port
    ];

    networking.firewall.interfaces.wpan0.allowedTCPPorts = [
      config.services.openthread-border-router.rest.listenPort
      config.services.openthread-border-router.web.listenPort
      config.services.matter-server.port
    ];

    services.openthread-border-router = {
      enable = true;
      logLevel = "debug";
      backboneInterfaces = [
        config.homelab.routing.interfaces.lan
      ];
      radio = {
        device = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_1a8fbb4676d9ee1190f5ab4c37b89984-if00-port0";
        baudRate = 460800;
        flowControl = false;
      };
      rest.listenAddress = "0.0.0.0";
      web.enable = true;
      web.listenAddress = "0.0.0.0";
    };

    services.matter-server.enable = true;
    systemd.services.matter-server = {
      path = with pkgs; [ chip-ota-provider-app ];
      serviceConfig.DynamicUser = lib.mkForce false;
    };

    hardware.bluetooth.enable = true;

    services.home-assistant.config.http = {
      server_host = "::1";
      trusted_proxies = [ "::1" ];
      use_x_forwarded_for = true;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "hass" ];
      ensureUsers = [
        {
          name = "hass";
          ensureDBOwnership = true;
        }
      ];
    };

    services.nginx.virtualHosts."home.${config.homelab.tld}" = {
      locations."/" = {
        proxyPass = "http://[::1]:${toString config.services.home-assistant.config.http.server_port}";
        proxyWebsockets = true;
      };
    };

    networking.domains.subDomains."home.${config.homelab.tld}" = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
    };
  };
}
