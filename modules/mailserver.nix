{ pkgs, config, lib, ... }:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
in {
  options.eilean.mailserver = {
    enable = mkEnableOption "mailserver";
    systemAccountPasswordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf cfg.mailserver.enable {
    mailserver = {
      enable = true;
      fqdn = "mail.${domain}";
      domains = [ "${domain}" ];

      loginAccounts = {
        "system@${domain}" = {
          passwordFile = cfg.mailserver.systemAccountPasswordFile;
          aliases = [
            (mkIf cfg.gitea.enable "git@${domain}")
            (mkIf cfg.mastodon.enable "mastodon@${domain}")
          ];
        };
      };

      # Use Let's Encrypt certificates. Note that this needs to set up a stripped
      # down nginx and opens port 80.
      certificateScheme = 3;

      localDnsResolver = false;
    };

    services.nginx.enable = true;
    services.nginx.virtualHosts."${config.mailserver.fqdn}".extraConfig = ''
      return 301 $scheme://${domain}$request_uri;
    '';

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [
      {
        name = "mail";
        type = "A";
        data = cfg.serverIpv4;
      }
      {
        name = "mail";
        type = "AAAA";
        data = cfg.serverIpv6;
      }
      {
        name = "@";
        type = "MX";
        data = "10 mail";
      }
      {
        name = "@";
        type = "TXT";
        data = "\"v=spf1 a:mail.${config.networking.domain} -all\"";
      }
      {
        name = "mail._domainkey";
        ttl = 10800;
        type = "TXT";
        data = "\"v=DKIM1; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC6YmYYvoFF7VqtGcozpVQa78aaGgZdvc5ZIHqzmkKdCBEyDF2FRbCEK4s2AlC8hhc8O4mSSe3S4AzEhlRgHXbU22GBaUZ3s2WHS8JJwZvWeTjsbXQwjN/U7xpkqXPHLH9IVfOJbHlp4HQmCAXw4NaypgkkxIGK0jaZHm2j6/1izQIDAQAB\"";
      }
      {
        name = "_dmarc";
        ttl = 10800;
        type = "TXT";
        data = "\"v=DMARC1; p=reject\"";
      }
    ];
  };
}
