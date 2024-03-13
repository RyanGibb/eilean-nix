{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
in
{
  options.eilean.turn = {
    enable = mkEnableOption "TURN server";
    secretFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf cfg.turn.enable {
    services.coturn = rec {
      enable = true;
      no-cli = true;
      no-tcp-relay = true;
      secure-stun = true;
      use-auth-secret = true;
      static-auth-secret-file = "${cfg.turn.secretFile}";
      realm = "turn.${domain}";
      relay-ips = with config.eilean; [
        serverIpv4
        serverIpv6
      ];
      cert = "${config.security.acme.certs.${realm}.directory}/full.pem";
      pkey = "${config.security.acme.certs.${realm}.directory}/key.pem";
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
      in {
        allowedTCPPorts = stun-ports;
        allowedTCPPortRanges = [ turn-range ];
        allowedUDPPorts = stun-ports;
        allowedUDPPortRanges = [ turn-range ];
    };

    security.acme.certs.${config.services.coturn.realm} = {
      postRun = "systemctl reload nginx.service; systemctl restart coturn.service";
      group = "turnserver";
    };
    services.nginx.enable = true;
    services.nginx.virtualHosts = {
      "${config.services.coturn.realm}" = {
        forceSSL = true;
        enableACME = true;
      };
    };
    users.groups."turnserver".members = [ config.services.nginx.user ];

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [
      {
        name = "turn";
        type = "CNAME";
        data = "vps";
      }
    ];
  };
}
