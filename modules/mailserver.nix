{
  pkgs,
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
  subdomain = "mail.${domain}";
in
{
  options.eilean.mailserver = {
    enable = mkEnableOption "mailserver";
    systemAccountPasswordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf cfg.mailserver.enable {
    security.acme-eon.certs."${subdomain}" = lib.mkIf cfg.acme-eon {
      group = "turnserver";
      reloadServices = [
        "postfix.service"
        "dovecot.service"
      ];
    };

    mailserver = {
      enable = true;
      fqdn = subdomain;
      domains = [ "${domain}" ];
      accounts = mkIf (cfg.gitea.enable || cfg.mastodon.enable) {
        "system@${domain}" = {
          passwordFile = cfg.mailserver.systemAccountPasswordFile;
          aliases = [
            (mkIf cfg.gitea.enable "git@${domain}")
            (mkIf cfg.mastodon.enable "mastodon@${domain}")
          ];
        };
      };

      # Use Let's Encrypt certificates: eon-managed certs when acme-eon is
      # enabled, otherwise an ACME host served by the local nginx below.
      x509 =
        if cfg.acme-eon then
          {
            certificateFile = "${config.security.acme-eon.certs.${subdomain}.directory}/fullchain.pem";
            privateKeyFile = "${config.security.acme-eon.certs.${subdomain}.directory}/key.pem";
          }
        else
          {
            useACMEHost = subdomain;
          };
      localDnsResolver = false;
    };

    services.nginx.enable = true;
    services.nginx.virtualHosts."${config.mailserver.fqdn}" = {
      enableACME = lib.mkIf (!cfg.acme-eon) true;
      forceSSL = lib.mkIf (!cfg.acme-eon) true;
      extraConfig = ''
        return 301 $scheme://${domain}$request_uri;
      '';
    };

    systemd.services.dovecot = lib.mkIf cfg.acme-eon {
      wants = [ "acme-eon-${subdomain}.service" ];
      after = [ "acme-eon-${subdomain}.service" ];
    };

    systemd.services.postfix = lib.mkIf cfg.acme-eon {
      wants = [ "acme-eon-${subdomain}.service" ];
      after = [ "acme-eon-${subdomain}.service" ];
    };

    services.postfix.settings.main = {
      smtpd_tls_protocols = mkForce "TLSv1.3, TLSv1.2, !TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
      smtp_tls_protocols = mkForce "TLSv1.3, TLSv1.2, !TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
      smtpd_tls_mandatory_protocols = mkForce "TLSv1.3, !TLSv1.2, TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
      smtp_tls_mandatory_protocols = mkForce "TLSv1.3, !TLSv1.2, TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
    };

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [
      {
        name = "mail";
        type = "A";
        value = cfg.serverIpv4;
      }
      {
        name = "mail";
        type = "AAAA";
        value = cfg.serverIpv6;
      }
      {
        name = "@";
        type = "MX";
        value = "10 mail";
      }
      {
        name = "@";
        type = "TXT";
        value = ''"v=spf1 a:mail.${config.networking.domain} -all"'';
      }
      {
        name = "_dmarc";
        ttl = 10800;
        type = "TXT";
        value = ''"v=DMARC1; p=reject"'';
      }
    ];
  };
}
