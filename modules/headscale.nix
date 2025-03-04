{ pkgs, config, lib, ... }:

with lib;
let cfg = config.eilean;
in {
  options.eilean.headscale = with lib; {
    enable = mkEnableOption "headscale";
    zone = mkOption {
      type = types.str;
      default = config.networking.domain;
      defaultText = "config.networking.domain";
    };
    domain = mkOption {
      type = types.str;
      default = "headscale.${config.networking.domain}";
      defaultText = "headscale.$\${config.networking.domain}";
    };
  };

  config = mkIf cfg.headscale.enable {
    # To set up:
    #   `headscale namespaces create <namespace_name>`
    # To add a node:
    #   `headscale --namespace <namespace_name> nodes register --key <machine_key>`
    services.headscale = {
      enable = true;
      # address = "127.0.0.1";
      port = 10000;
      settings = {
        server_url = "https://${cfg.headscale.domain}";
        logtail.enabled = false;
        ip_prefixes = [ "100.64.0.0/10" "fd7a:115c:a1e0::/48" ];
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.headscale.domain} = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = with config.services.headscale;
            "http://${address}:${toString port}";
          proxyWebsockets = true;
        };
      };
    };

    environment.systemPackages = [ config.services.headscale.package ];

    eilean.dns.enable = true;
    eilean.services.dns.zones.${cfg.headscale.zone}.records = [{
      name = "${cfg.headscale.domain}.";
      type = "CNAME";
      value = cfg.domainName;
    }];
  };
}
