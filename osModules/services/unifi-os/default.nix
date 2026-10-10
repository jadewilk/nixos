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
    extraOptions = [
      "--cgroupns=host"
      "--tz=local"
    ];
    tmpFs = {
      "/run" = [ "exec" ];
      "/run/lock" = [ ];
      "/tmp" = [ "exec" ];
      "/var/lib/journal" = [ ];
      "/var/opt/unifi/tmp" = [ "size=64m" ];
      "/data/unifi-core/config/http" = [ ];
    };
    # ports taken from https://github.com/unihosted/unifi-os-server-docker/blob/main/docker-compose.yaml
    ports = [
      "1900:1900/udp"
      "8080:8080"
      "8443:8443"
      "8444:8444"
      "8880-8882:8880-8882"
      "11443:443"
      "3478:3478/udp"
      "5514:5514/udp"
      "10003:10003/udp"
      "6789:6789"
      # maybe necessary?
      "5005:5005"
      "9543:9543"
      "11084:11084"
      "5671:5671"
    ];
    environment = {
      UOS_SYSTEM_IP = unifiDomain;
    };
  };

  networking.firewall.interfaces.${config.homelab.routing.interfaces.lan} = {
    allowedTCPPorts = [ 8080 ];
    allowedUDPPorts = [
      1900
      10001
    ];
  };

  homelab.dns.additionalLocalRecords = [ "unifi" ];

  networking.domains.subDomains.${unifiDomain} = {
    a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
    aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
  };

  services.nginx.virtualHosts.${unifiDomain} = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "https://127.0.0.1:11443";
      proxyWebsockets = true;
    };
  };
}
