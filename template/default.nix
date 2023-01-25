{ pkgs, config, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  eilean = {
    # TODO replace these values
    username = "user";
    secretsDir = "/secrets";
    serverIpv4 = "203.0.113.0";
    serverIpv6 = "2001:DB8::/64";
    publicInterface = "eth0";
    
    mailserver.enable = true;
    matrix.enable = true;
    turn.enable = true;
    mastodon.enable = true;
    gitea.enable = true;
    dns.enable = true;
  };

  # TODO replace this with domain
  networking.domain = "example.org";

  security.acme.acceptTerms = true;
}
