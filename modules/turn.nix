{
  config,
  pkgs,
  lib,
  ...
}:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
  subdomain = "turn.${domain}";
  staticAuthSecretFile = "/run/coturn/static-auth-secret";
in
{
  options.eilean.turn = {
    enable = mkEnableOption "TURN server";
  };

  config = mkIf cfg.turn.enable {
    security.acme-eon.certs."${subdomain}" = lib.mkIf cfg.acme-eon {
      group = "turnserver";
      reloadServices = [ "coturn" ];
    };

    services.coturn =
      let
        certDir =
          if cfg.acme-eon then
            config.security.acme-eon.certs.${subdomain}.directory
          else
            config.security.acme.certs.${subdomain}.directory;
      in
      {
        enable = true;
        no-cli = true;
        no-tcp-relay = true;
        secure-stun = true;
        use-auth-secret = true;
        static-auth-secret-file = staticAuthSecretFile;
        realm = subdomain;
        relay-ips = with config.eilean; [
          serverIpv4
          serverIpv6
        ];
        cert = "${certDir}/fullchain.pem";
        pkey = "${certDir}/key.pem";
      };

    systemd.services = {
      coturn-static-auth-secret-generator = {
        description = "Generate coturn static auth secret file";
        script = ''
          if [ ! -f '${staticAuthSecretFile}' ]; then
            umask 077
            DIR="$(dirname '${staticAuthSecretFile}')"
            mkdir -p "$DIR"
            tr -dc A-Za-z0-9 </dev/urandom | head -c 32 > '${staticAuthSecretFile}'
            chown -R ${config.systemd.services.coturn.serviceConfig.User}:${config.systemd.services.coturn.serviceConfig.Group} "$DIR"
          fi
        '';
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
      };
      "coturn" = {
        after = [
          "coturn-static-auth-secret-generator.service"
        ]
        ++ lib.lists.optional cfg.acme-eon "acme-eon-${subdomain}.service";
        requires = [ "coturn-static-auth-secret-generator.service" ];
        wants = lib.lists.optional cfg.acme-eon "acme-eon-${subdomain}.service";
      };
    };

    networking.firewall =
      with config.services.coturn;
      let
        turn-range = {
          from = min-port;
          to = max-port;
        };
        stun-ports = [
          listening-port
          tls-listening-port
          # these are only used if server has more than one IP address (of the same family
          #alt-listening-port
          #alt-tls-listening-port
        ];
      in
      {
        allowedTCPPorts = stun-ports;
        allowedTCPPortRanges = [ turn-range ];
        allowedUDPPorts = stun-ports;
        allowedUDPPortRanges = [ turn-range ];
      };

    security.acme.certs.${config.services.coturn.realm} = lib.mkIf (!cfg.acme-eon) {
      postRun = "systemctl reload nginx.service; systemctl restart coturn.service";
      group = "turnserver";
    };
    services.nginx.enable = lib.mkIf (!cfg.acme-eon) true;
    services.nginx.virtualHosts = lib.mkIf (!cfg.acme-eon) {
      "${config.services.coturn.realm}" = {
        forceSSL = true;
        enableACME = true;
      };
    };
    users.groups."turnserver".members = lib.mkIf (!cfg.acme-eon) [ config.services.nginx.user ];

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [
      {
        name = "turn";
        type = "CNAME";
        value = cfg.domainName;
      }
    ];
  };
}
