{ pkgs, config, lib, ... }:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
  subdomain = "mastodon.${domain}";
in {
  options.eilean.mastodon = { enable = mkEnableOption "mastodon"; };

  config = mkIf cfg.mastodon.enable {
    services.mastodon = {
      enable = true;
      enableUnixSocket = false;
      webProcesses = 1;
      webThreads = 3;
      sidekiqThreads = 5;
      streamingProcesses = 3;
      smtp = {
        #createLocally = false;
        user = "system@${domain}";
        port = 465;
        host = "mail.${domain}";
        authenticate = true;
        passwordFile = cfg.mailserver.systemAccountPasswordFile;
        fromAddress = "mastodon@${domain}";
      };
      extraConfig = {
        # override localDomain
        LOCAL_DOMAIN = domain;
        WEB_DOMAIN = subdomain;

        # https://peterbabic.dev/blog/setting-up-smtp-in-mastodon/
        SMTP_SSL = "true";
        SMTP_ENABLE_STARTTLS = "false";
        SMTP_OPENSSL_VERIFY_MODE = "none";
      };
    };

    users.groups.${config.services.mastodon.group}.members =
      [ config.services.nginx.user ];

    security.acme-eon.nginxCerts = lib.mkIf cfg.acme-eon [ subdomain ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        # relies on root domain being set up
        "${domain}".locations = {
          "/.well-known/host-meta".extraConfig = ''
            return 301 https://${subdomain}$request_uri;
          '';
          "/.well-known/webfinger".extraConfig = ''
            return 301 https://${subdomain}$request_uri;
          '';
        };
        "${subdomain}" = {
          root = "${config.services.mastodon.package}/public/";
          forceSSL = true;
          enableACME = lib.mkIf (!cfg.acme-eon) true;

          locations."/system/".alias = "/var/lib/mastodon/public-system/";

          locations."/" = { tryFiles = "$uri @proxy"; };

          locations."@proxy" = {
            proxyPass = "http://127.0.0.1:${
                builtins.toString config.services.mastodon.webPort
              }";
            proxyWebsockets = true;
          };
        };
      };
    };

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [{
      name = "mastodon";
      type = "CNAME";
      value = cfg.domainName;
    }];
  };
}
