{ pkgs, config, lib, ... }:

let
  cfg = config.eilean;
in {
  options.eilean.headscale = with lib; {
    enable = mkEnableOption "headscale";
    zone = mkOption {
      type = types.str;
      default = "${config.networking.domain}";
    };
    domain = mkOption {
      type = types.str;
      default = "headscale.${config.networking.domain}";
    };
  };

  config = lib.mkIf cfg.headscale.enable {
    # To set up:
    #   `headscale namespaces create <namespace_name>`
    # To add a node:
    #   `headscale --namespace <namespace_name> nodes register --key <machine_key>`
    services.headscale = {
      enable = true;
      # address = "127.0.0.1";
      port = 10000;
      serverUrl = "https://${cfg.headscale.domain}";
      dns = {
        # magicDns = true;
        nameservers = config.networking.nameservers;
        baseDomain = "${cfg.headscale.zone}";
      };
      settings = {
        logtail.enabled = false;
        ip_prefixes = [ "100.64.0.0/10" ];
      };
    };

    services.nginx.virtualHosts.${cfg.headscale.domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = with config.services.headscale;
          "http://${address}:${toString port}";
        proxyWebsockets = true;
      };
    };

    environment.systemPackages = [ config.services.headscale.package ];

    dns.zones.${cfg.headscale.zone}.records = [
      {
        name = "${cfg.headscale.domain}.";
        type = "CNAME";
        data = "vps";
      }
    ];
  };
}
