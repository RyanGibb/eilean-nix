{ config, pkgs, lib, ... }:

let
  cfg = config.eilean;
  domain = config.networking.domain;
in
{
  options.eilean.turn.enable = lib.mkEnableOption "TURN server";

  config = lib.mkIf cfg.turn.enable {
    services.coturn = rec {
      enable = true;
      no-cli = true;
      no-tcp-relay = true;
      min-port = 49000;
      max-port = 50000;
      use-auth-secret = true;
      static-auth-secret-file = "${config.eilean.secretsDir}/coturn";
      realm = "turn.${domain}";
      cert = "${config.security.acme.certs.${realm}.directory}/full.pem";
      pkey = "${config.security.acme.certs.${realm}.directory}/key.pem";
      secure-stun = true;
    };

    networking.firewall =
      let
        turn-range = with config.services.coturn; {
          from = min-port;
          to = max-port;
        };
        stun-port = 3478;
      in {
        allowedTCPPorts = lib.mkForce [ stun-port ];
        allowedTCPPortRanges = [ turn-range ];
        allowedUDPPorts = lib.mkForce [ stun-port ];
        allowedUDPPortRanges = [ turn-range ];
    };

    security.acme.certs.${config.services.coturn.realm} = {
      postRun = "systemctl reload nginx.service; systemctl restart coturn.service";
      group = "turnserver";
    };
    services.nginx.virtualHosts = {
      "turn.${domain}" = {
        forceSSL = true;
        enableACME = true;
      };
    };
    users.groups."turnserver".members = [ config.services.nginx.user ];

    dns.zones.${config.networking.domain}.records = [
      {
        name = "turn";
        type = "CNAME";
        data = "vps";
      }
    ];
  };
}
