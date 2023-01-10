{
  imports = [
    ./dns/default.nix
    ./mailserver/default.nix
    ./hosting/default.nix
    ./hosting/mastodon.nix
    ./hosting/mailserver.nix
    ./hosting/gitea.nix
    ./hosting/dns.nix
    ./hosting/matrix.nix
    ./hosting/turn.nix
    ./wireguard/server.nix
    ./wireguard/default.nix
  ];
}