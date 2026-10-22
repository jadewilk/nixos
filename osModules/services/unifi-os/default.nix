{
  pkgs,
  config,
  ...
}:
let
  fetchImage =
    url:
    pkgs.runCommand "image.tar"
      {
        src = pkgs.fetchurl {
          inherit url;
          hash = "sha256-9hEek5akLHQBb13emwH770hqb+ae/hN5Nebji3wi+U0=";
        };
      }
      ''
        ${pkgs.unzip}/bin/unzip -p $src image.tar > $out || (($?==1))
      '';
  version = "5.1.42";
  arch = "linux-x64";
  imageFile = fetchImage "https://fw-download.ubnt.com/data/unifi-os-server/5172-linux-x64-5.1.42-12e9e3cf-8f8b-4e54-928c-76b80a10c8a4.42-x64";
  image = "oci-archive:${imageFile}";

  hostStateDirectory = "/var/lib/uos-server";
  volumes = [
    "/sys/fs/cgroup:/sys/fs/cgroup:rw"
    "${hostStateDirectory}/persistent:/persistent"
    "${hostStateDirectory}/var/log:/var/log"
    "${hostStateDirectory}/data/:/data"
    "${hostStateDirectory}/srv:/srv"
    "${hostStateDirectory}/var/lib/unifi:/var/lib/unifi"
    "${hostStateDirectory}/var/lib/mongodb:/var/lib/mongodb"
    "${hostStateDirectory}/etc/rabbitmq/ssl:/etc/rabbitmq/ssl"
    "${entryPointScript}:/entrypoint.sh:ro"
  ];

  unifiDomain = "unifi.${config.homelab.tld}";
  unifiNetwork = "uosservernetwork";
  unifiNetworkShim = "uosservernetwork-shim";
  unifiControllerIp = "192.168.1.3";
  unifiNetworkShimIp = "192.168.1.4";

  # see https://github.com/unihosted/unifi-os-server-docker/blob/91144ab74f2703b4713d22cc882303f37a71b72d/uos-entrypoint.sh#L216
  entryPointScript = pkgs.writeScript "entrypoint.sh" ''
    #!/bin/bash

    DATA_DIR="/data"

     if [ ! -f "$DATA_DIR/uos_uuid" ]; then
        RAW_UUID=$(cat /proc/sys/kernel/random/uuid)
        # Force the version nibble to 5 so UOS treats the id as a v5 UUID.
        UOS_UUID=$(echo "$RAW_UUID" | sed 's/./5/15')
        echo "Generated UOS_UUID=$UOS_UUID"
        echo "$UOS_UUID" > $DATA_DIR/uos_uuid
    else
        printf "Using exising stored UUID $(cat $DATA_DIR/uos_uuid)"
        UOS_UUID=$(cat $DATA_DIR/uos_uuid)
    fi

    echo "${arch}" > /usr/lib/platform
    echo "UOSSERVER" > /usr/lib/app_model
    echo "UniFi OS Server" > /usr/lib/product_name
    echo "UOSSERVER.0000000.${version}.0000000.000000.0000" > /usr/lib/version

    ensure_dir() {
        local dir="$1" owner="$2"
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chown "$owner" "$dir"
            chmod 755 "$dir"
        fi
    }


    ensure_dir "/var/log/nginx"     "nginx:nginx"
    ensure_dir "/var/log/mongodb"   "mongodb:mongodb"
    ensure_dir "/var/log/rabbitmq"  "rabbitmq:rabbitmq"

    chown -R mongodb:mongodb /var/lib/mongodb


    if [ ! -d /sys/devices/virtual/net/eth0 ] && [ -d /sys/devices/virtual/net/tap0 ]; then
        ip link add name eth0 link tap0 type macvlan
        ip link set eth0 up
    fi

    exec 3>&1
    (
        # Wait until systemd-journald has created its journal files.
        # journalctl exits 0 even without files, so check its output instead.
        while journalctl -n 0 2>&1 | grep -q "No journal files were found"; do
            sleep 1
        done
        exec journalctl -f --no-hostname -o short >&3 2>&3
    ) &

    exec /sbin/init
  '';
in
{
  # see https://www.unihosted.com/blog/running-unifi-os-server-in-docker
  # and https://github.com/leo60228/dotfiles/blob/395b43495bf499310589996b0b16ae93c082e401/systems/greenhouse/default.nix#L154-L210
  virtualisation.oci-containers.containers.uosserver = {
    inherit imageFile image volumes;
    entrypoint = "/entrypoint.sh";
    capabilities = {
      NET_RAW = true;
      NET_ADMIN = true;
    };
    networks = [
      unifiNetwork
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--add-host=host.containers.internal:host-gateway"
      "--systemd=always"
      "--cgroupns=host"
      "--tz=local"
      "--pids-limit=8192"
      "--ip=${unifiControllerIp}"
    ];
    tmpFs = {
      "/run" = [ "exec" ];
      "/run/lock" = [ ];
      "/tmp" = [ "exec" ];
      "/var/lib/journal" = [ ];
      "/var/opt/unifi/tmp" = [ "size=64m" ];
      "/data/unifi-core/config/http" = [ ];
    };
    environment = {
      UOS_SYSTEM_IP = unifiControllerIp;
    };
  };

  homelab.dns.additionalLocalRecords = {
    "unifi" = unifiControllerIp;
  };

  networking.domains.subDomains.${unifiDomain} = {
    a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
    aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
  };

  services.nginx.virtualHosts.${unifiDomain} = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "https://${unifiControllerIp}:443";
      proxyWebsockets = true;
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host $proxy_host;
        proxy_set_header Origin "";
        proxy_set_header Referer "";

        proxy_connect_timeout 60s;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };

  systemd.sockets.netavark-dhcp-proxy = {
    description = "Netavark DHCP proxy socket";
    socketConfig = {

      SocketGroup = "podman";
      ListenStream = "%t/podman/nv-proxy.sock";
      SocketMode = "0660";
    };

    wantedBy = [ "sockets.target" ];
  };

  systemd.services.netavark-dhcp-proxy = {
    description = "Netavark DHCP proxy service";

    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.netavark}/bin/netavark dhcp-proxy -a 30";
    };

    after = [ "netavark-dhcp-proxy.socket" ];
    requires = [ "netavark-dhcp-proxy.socket" ];
    startLimitIntervalSec = 0;

    wantedBy = [ "default.target" ];
  };

  systemd.network.netdevs = {
    "5-${unifiNetworkShim}" = {
      netdevConfig = {
        Kind = "macvlan";
        Name = unifiNetworkShim;
      };
      macvlanConfig = {
        Mode = "bridge";
      };
    };
  };
  systemd.network.networks = {
    "15-${config.homelab.routing.interfaces.lan}" = {
      macvlan = [
        unifiNetworkShim
      ];
    };
    "15-${unifiNetworkShim}" = {
      matchConfig.Name = unifiNetworkShim;
      matchConfig.Type = "ether";
      networkConfig = {
        Address = "${unifiNetworkShimIp}/16";
      };
      routes = [
        {
          Destination = "${unifiControllerIp}/32";
        }
      ];
    };
  };
}
