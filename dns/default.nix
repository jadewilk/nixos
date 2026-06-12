{
  defaultTTL = 3600;
  zones = {
    "fogbox.uk"."".ns.data = [
      "ns1.desec.io"
      "ns2.desec.org"
    ];
    "jadewilk.uk" = {
      "" = {
        ns.data = [
          "ns1.desec.io"
          "ns2.desec.org"
        ];
        mx.data = [
          {
            exchange = "mxext1.mailbox.org";
            preference = 10;
          }
          {
            exchange = "mxext2.mailbox.org";
            preference = 10;
          }
          {
            exchange = "mxext3.mailbox.org";
            preference = 20;
          }
        ];
        txt.data = "v=spf1 include:mailbox.org -all";
      };
      "31f642ac004a5d83377f2e786b2b7de820d24d8e".txt.data = "a0bacc07fba4608e08a40e8e44592e1aa778b8f5";
      "MBO0001._domainkey".cname.data = "MBO0001._domainkey.mailbox.org";
      "MBO0002._domainkey".cname.data = "MBO0002._domainkey.mailbox.org";
      "MBO0003._domainkey".cname.data = "MBO0003._domainkey.mailbox.org";
      "MBO0004._domainkey".cname.data = "MBO0004._domainkey.mailbox.org";
      "_dmarc".txt.data = "v=DMARC1;p=reject;rua=mailto:postmaster@jadewilk.uk";
      "autoconfig".cname.data = "auto.mailbox.org";
      "_autodiscover._tcp".srv.data = {
        port = 443;
        priority = 0;
        target = "auto.mailbox.org";
        weight = 0;
      };
      "_hkps._tcp".srv.data = {
        port = 443;
        priority = 1;
        weight = 1;
        target = "pgp.mailbox.org";
      };
      "_caldavs._tcp".srv.data = {
        port = 443;
        priority = 0;
        weight = 0;
        target = "dav.mailbox.org";
      };
      "_carddavs._tcp".srv.data = {
        port = 443;
        priority = 0;
        weight = 0;
        target = "dav.mailbox.org";
      };
    };
  };
}
