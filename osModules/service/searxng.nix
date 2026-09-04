{
  lib,
  config,
  pkgs,
  ...
}:
let
  domain = "search.${config.homelab.tld}";
in
{
  options.homelab.services.searxng.enable = lib.mkEnableOption "the searxng search engine";

  config = lib.mkIf config.homelab.services.searxng.enable {
    age.secrets.searxng_sec.file = ../../secrets/searxng/sec.age;

    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        extraConfig = ''
          uwsgi_pass unix:${config.services.searx.uwsgiConfig.socket};
        '';
      };
    };

    networking.domains.subDomains.${domain} = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
    };

    systemd.services.nginx.serviceConfig.ProtectHome = false;
    users.groups.searx.members = [ "nginx" ];

    services.searx = {
      enable = true;
      package = pkgs.searxng;
      redisCreateLocally = true;

      limiterSettings = {
        real_ip = {
          x_for = 1;

          ipv4_prefix = 32;
          ipv6_prefix = 56;
        };
        botdetection = {
          ip_limit = {
            filter_link_local = true;
            link_token = true;
          };
          ip_lists = {
            pass_ip = [
              "192.168.0.0/16"
              "fe80::/10"
            ];
            pass_searxng_org = true;
          };
        };
      };

      settings = {
        use_default_settings = true;
        general = {
          instance_name = "SearXNG";
          #enable_metrics = false;
        };
        server = {
          port = 8080;
          bind_address = "0.0.0.0";
          limiter = true;
          image_proxy = true;
          base_url = "https://${domain}";
          public_instance = true;
          default_locale = "en";
          default_lang = "en-GB";
          secret_key = config.age.secrets.searxng_sec.path;
        };
        ui = {
          static_use_hash = true;
          query_in_title = true;
        };
        search = {
          safe_search = 0;
          default_lang = "en-GB";
          autocomplete = "duckduckgo";
        };
        # upstream list of plugins
        # https://docs.searxng.org/admin/plugins.html
        enabled_plugins = [
          "Hash plugin"
          "Self Information"
          "Tor check plugin"
          "Hostnames plugin"
          "Basic Calculator"
          "Tracker URL remover"
          "Ahmia blacklist"
          "Open Access DOI rewrite"
        ];

        hostnames.remove = [
          "(.*\\.)?geeksforgeeks.org$"
        ];

        hostnames.replace = {
          "(.*\\.)?nixos.wiki$" = "wiki.nixos.org";
        };

        # upstream list of built-in search engines
        # https://docs.searxng.org/user/configured_engines.html
        engines =
          let
            pageSize = 100;
          in
          (lib.mapAttrsToList (name: value: { inherit name; } // value) {
            # General search
            "duckduckgo".disabled = false;
            "bing".disabled = true;
            "google".disabled = true;
            "brave".disabled = true;
            "google_cse".disable = true;
            # IT/Development
            "crates.io".disabled = false;
            "npm".disabled = false;
            "pub.dev".disabled = false;
            "pkg.go.dev".disabled = false;
            # Git repos
            "gitlab".disabled = false;
            "codeberg".disabled = false;
            "bitbucket".disabled = false;
            "sourcehut".disabled = false;
            # maps
            "apple maps".disabled = false;
          })
          ++
            # upstream list of built-in meta engines
            # https://docs.searxng.org/dev/engines/index.html#online-engines
            [
              {
                name = "nixos wiki";
                shortcut = "nw";
                engine = "mediawiki";
                base_url = "https://wiki.nixos.org/";
                categories = [
                  "it"
                  "nix"
                ];
                timeout = 3;
                disabled = false;
              }
            ];
        outgoing = {
          request_timeout = 5.0;
          max_request_timeout = 15.0;
          pool_connections = 100;
          pool_maxsize = 15;
          enable_http2 = true;
        };
      };

      configureUwsgi = true;

      uwsgiConfig = {
        socket = "/run/searx/searx.sock";
        http = ":8888";
        chmod-socket = "660";
        disable-logging = true;
      };
    };
  };
}
