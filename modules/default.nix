{ pkgs, lib, config, ... }:

with lib;

{
  imports = [
    ./services/dns/default.nix
    ./mastodon.nix
    ./mailserver.nix
    ./gitea.nix
    ./dns.nix
    ./matrix/synapse.nix
    ./matrix/mautrix-signal.nix
    ./matrix/mautrix-instagram.nix
    ./matrix/mautrix-messenger.nix
    ./turn.nix
    ./headscale.nix
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
    # TODO install manpage
    environment.systemPackages = [
    ];
    security.acme.defaults.email = "${config.eilean.username}@${config.networking.domain}";
    networking.firewall.allowedTCPPorts = mkIf config.services.nginx.enable [
      80 # HTTP
      443 # HTTPS
    ];
  };
}
