{
  config,
  lib,
  pkgs,
  ...
}:
let
  svcDomain = "services.${domain}";
  domain = config.homelab.services.email.domain;
  autoDiscover = "autodiscover.${domain}";
  autoConfig = "autoconfig.${domain}";
  webmail_domain = config.homelab.services.email.web;
  mail_selfservice_domain = "selfservice.${config.homelab.tld}";
  userSuffix = "ou=users,${ldapSuffix}";
  ldapSuffix = config.services.openldap.settings.children."olcDatabase={1}mdb".attrs.olcSuffix;
  stateDir = "${config.homelab.stateDir}/stalwart-mail";
  credPath = "/run/credentials/stalwart.service";
in
{
  options.homelab.services.email = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Whether to enable the email server.
      '';
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = config.homelab.tld;
      example = "fogbox.uk";
      description = ''
        Domain for postfix email server.
      '';
    };
    web = lib.mkOption {
      type = lib.types.str;
      default = "mail.${config.homelab.services.email.domain}";
      example = "mail.fogbox.uk";
      description = ''
        Domain for webmail access.
      '';
    };
  };

  config = lib.mkIf config.homelab.services.email.enable {
    age.secrets = {
      mail_ldap.file = ../../secrets/mail_ldap.age;
      mail_admin.file = ../../secrets/mail_admin.age;
      mail_pwd.file = ../../secrets/mail_pwd.age;
      "${domain}-rsa".file = ../../secrets/mail/${"${domain}-rsa"}.age;
      "${domain}-ed25519".file = ../../secrets/mail/${"${domain}-ed25519"}.age;
      "${svcDomain}-rsa".file = ../../secrets/mail/${"${svcDomain}-rsa"}.age;
      "${svcDomain}-ed25519".file = ../../secrets/mail/${"${svcDomain}-ed25519"}.age;
    };

    security.acme.certs = {
      "${domain}".reloadServices = [ "stalwart" ];
      "${svcDomain}".reloadServices = [ "stalwart" ];
    };

    systemd.services.stalwart = {
      wants = [
        "acme-${domain}.service"
        "acme-${svcDomain}.service"
      ];
      after = [
        "acme-${domain}.service"
        "acme-${svcDomain}.service"
      ];
      serviceConfig = {
        LoadCredential = [
          "${domain}-cert.pem:${config.security.acme.certs.${domain}.directory}/cert.pem"
          "${domain}-key.pem:${config.security.acme.certs.${domain}.directory}/key.pem"
          "${svcDomain}-cert.pem:${config.security.acme.certs.${svcDomain}.directory}/cert.pem"
          "${svcDomain}-key.pem:${config.security.acme.certs.${svcDomain}.directory}/key.pem"
          "adminPwd:${config.age.secrets.mail_admin.path}"
          "ldapPwd:${config.age.secrets.mail_ldap.path}"
          "mailPwd:${config.age.secrets.mail_pwd.path}"
          "${domain}-rsa.key:${config.age.secrets."${domain}-rsa".path}"
          "${domain}-ed25519.key:${config.age.secrets."${domain}-ed25519".path}"
          "${svcDomain}-rsa.key:${config.age.secrets."${svcDomain}-rsa".path}"
          "${svcDomain}-ed25519.key:${config.age.secrets."${svcDomain}-ed25519".path}"
        ];
        ReadWritePaths = "${stateDir}";
      };
    };

    networking.firewall.interfaces.${config.homelab.routing.interfaces.lan}.allowedTCPPorts = [
      25
      465
      993
    ];

    services.nginx.virtualHosts = {
      "${mail_selfservice_domain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8119";
          proxyWebsockets = true;
        };
      };
      "jmap.${domain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8120";
          proxyWebsockets = true;
        };
      };
      "${autoConfig}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8119";
          proxyWebsockets = true;
        };
      };
      "${autoDiscover}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8119";
          proxyWebsockets = true;
        };
      };
    };

    networking.domains.baseDomains.${config.homelab.tld} = {
      a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
      aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;

    };

    networking.domains.subDomains = {
      ${domain} = {
        mx.data = {
          exchange = domain;
          preference = 10;
        };
        txt.data = [
          "v=STSv1\; id=1"
          "v=spf1 mx -all"
        ];
      };
      "_25._tcp.${domain}".tlsa.data = [
        {
          certificateAssociationData = "d016e1fe311948aca64f2de44ce86c9a51ca041df6103bb52a88eb3f761f57d7";
          usage = 2;
          selector = 1;
          matchingType = 1;
        }
        {
          certificateAssociationData = "f8a2b4e23e82a4494e9998fcc4242bef1277656a118beede55ddfadcb82e20c5dc036dcb3b6c48d2ce04e362a9f477c82ad5a557b06b6f33b45ca6662b37c1c9";
          usage = 2;
          selector = 1;
          matchingType = 2;
        }
        {
          certificateAssociationData = "d1bc8e794c79b922996681fb4730b672d6019d2467023e8f346bc76ddd1c26e7";
          usage = 3;
          selector = 0;
          matchingType = 1;
        }
        {
          certificateAssociationData = "b2ea2aeba149f49a39d936b6072fe7874aba318a348b03f0e690f0761a2fce1df3034f58c73813b90773dee4b906b4a5485f332829b984e36aa548a5ec9b2806";
          usage = 3;
          selector = 0;
          matchingType = 2;
        }
        {
          certificateAssociationData = "f38a5c614a2bc41f780babf19b0416bc6e57b4dc365e2d46ea1a74631d0ba640";
          usage = 3;
          selector = 1;
          matchingType = 1;
        }
        {
          certificateAssociationData = "4868101a5923a8236d6657cfc5fa633c8b40badb8c5afe7c754e91a17ee61e7a649038db9139550e922a248eab6e47ccef1d4e4e0079885cd3cefc2d5ab5e010";
          usage = 3;
          selector = 1;
          matchingType = 2;
        }
      ];
      "_25._tcp.${svcDomain}".tlsa.data = [
        {
          certificateAssociationData = "a32bd1dde809ade2d815e6eb54c5704571f666e295995bd1015209f89167abf4";
          usage = 3;
          matchingType = 1;
          selector = 0;
        }
        {
          certificateAssociationData = "4303e868ad8e473ba5115d85a5e9a5f7c02e04f383c50a220bec594c3afe368cd896b12ff7aeb225ed151e3777dc9be0954506b50ae063c00063c4cff696e728";
          usage = 3;
          matchingType = 2;
          selector = 0;
        }
        {
          certificateAssociationData = "8758e76e7ee2e1a40c847ee4040cd9da891052d113d20f8a5bb5a172f4cea3be";
          usage = 3;
          matchingType = 1;
          selector = 1;
        }
        {
          certificateAssociationData = "d14014fdc68ea13351266e4f6a83a81a6f7a0f28fc45b45c5758be308f687b5a8cbfe1e3b0e4ce51c1d315645a086f42315a630f6cbdc63f2975b50ac451422f";
          usage = 3;
          matchingType = 2;
          selector = 1;
        }
      ];
      "_autodiscover._tcp.${domain}".srv.data = {
        port = 443;
        priority = 0;
        target = autoDiscover;
        weight = 0;
      };
      "_dmarc.${domain}".txt.data =
        "v=DMARC1\; p=reject\; rua=mailto:26af011a@in.mailhardener.com\; ruf=mailto:26af011a@in.mailhardener.com";
      "_imaps._tcp.${domain}".srv.data = {
        port = 993;
        priority = 0;
        target = domain;
        weight = 1;
      };
      "_smtp._tls.${domain}".txt.data = "v=TLSRPTv1\; rua=mailto:postmaster@fogbox.uk";
      "_submissions._tcp.${domain}".srv.data = {
        port = 465;
        priority = 0;
        target = domain;
        weight = 1;
      };
      ${autoConfig} = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
      ${autoDiscover} = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
      "ed25519._domainkey.${domain}".txt.data =
        "v=DKIM1\; k=ed25519\; h=sha256\;  p=s/W3ANKFxjoNMOExp2qERf8n6xG5luqsc4zMi7N3STs=";
      "ed25519._domainkey.${svcDomain}".txt.data =
        "v=DKIM1\; k=ed25519\; h=sha256\; p=E/tuN0Wl3tKmrsNCSjPEXySuZnEAQ=";
      "imap.${domain}" = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
      ${webmail_domain} = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
      "rsa._domainkey.${domain}".txt.data =
        "v=DKIM1\; k=rsa\; h=sha256\; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Na56hadA75MTKusFYd385gj4CcCZ8q4T9gsjtTnp3MK1zlXerM3BLKUL4f/v/YKdZR8wEd/Z9CSc++6XXEVR+pQTBzaBKc9o05ZJRFY5zLFM5asGrwba5cNFQrSjzTlGz/d/886TUFFTIlTBqoiMgM9yY/5nW9LYj5Rb+XX65XnF1V+p8g4iDz1S3OmjTFMGqXSsD4deFI77Q7NVKUQTLQgjkjl2awrD3sOQEGshHFDtSHrdajs8ohAYXbXZPlBgnP+SY1XJwfNOdTIX5sadU2MvsjArhJyKt69dwezFq+pm6e4pL+0nP2rJyzPSI8vWe+q2GYcT08wyKdKc7uvjQIDAQAB";
      "rsa._domainkey.${svcDomain}".txt.data =
        "v=DKIM1\; k=rsa\; h=sha256\; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvaInXJBK5kzhAxDeUd+Fz6S86WtH7z7L+mZK6Cb6xOGKzeY9emjQUgjLz9EfTPIbmCLQAjBaoSJbSMZXsQFZe9ruW6fKV7dnKYklb42sxHOyKpeip5XBaPK9KeFl4680fZbB309NTlpNH9whjyFavwSj4zfZtCV4sa7Ker8s6HiTFgKpr2b8C1Tz12u5TYFWoP5t17wEcQofxW0U8y32H8SCsjARDvxgdwzxRBRvIPPDLF3lBVFrRLIsKKduI8bOSmZX+1cFddwlyJGRWiDozxzW1EufUR3W0YFdfCdy2V/xn+OHNsBsnDPCDVhbEeBHJvDDslnIrIE8Sa1cFbVHIQIDAQAB";
      ${mail_selfservice_domain} = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
      ${svcDomain} = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
      "smtp.${domain}" = {
        a.data = config.networking.domains.subDomains.${config.networking.fqdn}.a.data;
        aaaa.data = config.networking.domains.subDomains.${config.networking.fqdn}.aaaa.data;
      };
    };

    services.stalwart = {
      enable = true;
      stateVersion = "24.11";
      settings = {
        certificate.${domain} = {
          cert = "%{file:${credPath}/${domain}-cert.pem}%";
          private-key = "%{file:${credPath}/${domain}-key.pem}%";
          default = true;
        };

        certificate.${svcDomain} = {
          cert = "%{file:${credPath}/${svcDomain}-cert.pem}%";
          private-key = "%{file:${credPath}/${svcDomain}-key.pem}%";
        };

        lookup.default.hostname = domain;

        server = {
          listener = {
            smtp = {
              bind = [ "[::]:25" ];
              protocol = "smtp";
            };
            submissions = {
              bind = [ "[::]:465" ];
              protocol = "smtp";
              tls.implicit = true;
            };
            imaptls = {
              bind = [ "[::]:993" ];
              protocol = "imap";
              tls.implicit = true;
            };
            management = {
              bind = [ "127.0.0.1:8119" ];
              protocol = "http";
            };
            jmap = {
              bind = [ "127.0.0.1:8120" ];
              protocol = "http";
            };
          };
        };

        store = {
          data = {
            type = "rocksdb";
            path = "${stateDir}/data";
          };
          blob = {
            type = "rocksdb";
            path = "${stateDir}/blob";
          };
          fts = {
            type = "rocksdb";
            path = "${stateDir}/fts";
          };
          lookup = {
            type = "rocksdb";
            path = "${stateDir}/lookup";
          };
        };

        storage = {
          directory = "openldap";
          data = "data";
          blob = "blob";
          fts = "fts";
          lookup = "lookup";
        };

        directory.memory = {
          type = "memory";
          principals = [
            {
              name = "philipwilk";
              class = "individual";
              secret = "%{file:${credPath}/mailPwd}%";
              email = [ "philipwilk@${domain}" ];
            }
          ];
        };

        directory.openldap = {
          type = "ldap";
          url = "ldaps://ldap.fogbox.uk";
          base-dn = "${ldapSuffix}";
          timeout = "30s";
          tls.enable = true;
          bind = {
            enable = true;
            dn = "uid=mail,${userSuffix}";
            secret = "%{file:${credPath}/ldapPwd}%";
            auth = {
              enable = true;
              dn = "uid=?,${userSuffix}";
            };
          };
          filter = {
            name = "(&(objectClass=inetOrgPerson)(uid=?))";
            email = "(&(objectClass=inetOrgPerson)(|(mail=?)(mailAlias=?)(mailList=?)))";
            verify = "(&(objectClass=inetOrgPerson)(|(mail=*?*)(mailAlias=*?*)))";
            expand = "(&(objectClass=inetOrgPerson)(mailList=?))";
            domains = "(&(objectClass=inetOrgPerson)(|(mail=*@?)(mailAlias=*@?)))";
          };
          attributes = {
            name = "uid";
            class = "inetOrgPerson";
            description = [ "description" ];
            secret = "userPassword";
            email = "mail";
            # groups = [ "memberOf" ];
            # quota = "diskQuota";
          };
        };

        tracer = {
          stdout = {
            type = "stdout";
            level = "debug";
            ansi = true;
            enable = true;
          };
          journal = {
            type = "journal";
            level = "debug";
            enable = true;
          };
        };

        auth.dkim.sign = [
          {
            "if" = "is_local_domain('', sender_domain)";
            "then" = "[sender_domain + '-rsa', sender_domain + '-ed25519']";
          }
          { "else" = false; }
        ];

        signature."${domain}-rsa" = {
          private-key = "%{file:${credPath}/${domain}-rsa.key}%";
          domain = domain;
          selector = "rsa";
          headers = [
            "From"
            "To"
            "Date"
            "Subject"
            "Message-ID"
          ];
          algorithm = "rsa-sha256";
          canonicalization = "relaxed/relaxed";
          set-body-length = true;
          report = true;
        };

        signature."${domain}-ed25519" = {
          private-key = "%{file:${credPath}/${domain}-ed25519.key}%";
          domain = domain;
          selector = "ed25519";
          headers = [
            "From"
            "To"
            "Date"
            "Subject"
            "Message-ID"
          ];
          algorithm = "ed25519-sha256";
          canonicalization = "relaxed/relaxed";
          set-body-length = true;
          report = true;
        };

        signature."${svcDomain}-rsa" = {
          private-key = "%{file:${credPath}/${svcDomain}-rsa.key}%";
          domain = svcDomain;
          selector = "rsa";
          headers = [
            "From"
            "To"
            "Date"
            "Subject"
            "Message-ID"
          ];
          algorithm = "rsa-sha256";
          canonicalization = "relaxed/relaxed";
          set-body-length = true;
          report = true;
        };

        signature."${svcDomain}-ed25519" = {
          private-key = "%{file:${credPath}/${svcDomain}-ed25519.key}%";
          domain = svcDomain;
          selector = "ed25519";
          headers = [
            "From"
            "To"
            "Date"
            "Subject"
            "Message-ID"
          ];
          algorithm = "ed25519-sha256";
          canonicalization = "relaxed/relaxed";
          set-body-length = true;
          report = true;
        };

        authentication.fallback-admin = {
          user = "admin";
          secret = "%{file:${credPath}/adminPwd}%";
        };
      };
    };
  };
}
