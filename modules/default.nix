{ lib, config, ... }:

with lib;

{
  imports = [
    ./services/dns/default.nix
    ./mailserver/default.nix
    ./mastodon.nix
    ./mailserver.nix
    ./gitea.nix
    ./dns.nix
    ./matrix.nix
    ./turn.nix
    ./headscale.nix
    ./wireguard/server.nix
    ./wireguard/default.nix
  ];

  options.eilean = with types; {
    username = mkOption {
      type = str;
    };
    serverIpv4 = mkOption {
      type = str;
    };
    serverIpv6 = mkOption {
      type = str;
    };
    publicInterface = mkOption {
      type = str;
    };
  };

  config = {
    security.acme.defaults.email = "${config.eilean.username}@${config.networking.domain}";
    networking.firewall.allowedTCPPorts = mkIf config.services.nginx.enable [
      80 # HTTP
      443 # HTTPS
    ];
  };
}
