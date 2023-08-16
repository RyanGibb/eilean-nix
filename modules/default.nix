{ lib, config, ... }:

with lib;

{
  imports = [
    ./dns/default.nix
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
    secretsDir = mkOption {
      type = path;
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
    networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [
      80 # HTTP
      443 # HTTPS
    ];
  };
}
