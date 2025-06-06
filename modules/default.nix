{ pkgs, lib, config, ... }:

with lib;

{
  imports = [
    ./acme-eon.nix
    ./services/dns/default.nix
    ./mastodon.nix
    ./mailserver.nix
    ./gitea.nix
    ./dns.nix
    ./fail2ban.nix
    ./matrix/synapse.nix
    ./matrix/mautrix-instagram.nix
    ./matrix/mautrix-messenger.nix
    ./turn.nix
    ./headscale.nix
    ./wireguard/default.nix
    ./radicale.nix
  ];

  options.eilean = with types; {
    username = mkOption { type = str; };
    serverIpv4 = mkOption { type = str; };
    serverIpv6 = mkOption { type = str; };
    publicInterface = mkOption { type = str; };
    domainName = mkOption {
      type = types.str;
      default = "vps";
    };
  };

  config = {
    # TODO install manpage
    environment.systemPackages = [ ];
    security.acme.defaults.email = lib.mkIf (!config.eilean.acme-eon)
      "${config.eilean.username}@${config.networking.domain}";
    security.acme-eon.defaults.email = lib.mkIf config.eilean.acme-eon
      "${config.eilean.username}@${config.networking.domain}";
    networking.firewall.allowedTCPPorts = mkIf config.services.nginx.enable [
      80 # HTTP
      443 # HTTPS
    ];
  };
}
