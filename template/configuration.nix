{ pkgs, config, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "22.11";

  services.openssh = {
    enable = true;
    settings.passwordAuthentication = false;
  };

  environment.systemPackages = with pkgs; [
    git # for nix flakes
    vim # for editing config files
  ];

  users.users.root = {
    initialHashedPassword = "";
    users.users.root.openssh.authorizedKeys.keys = [
      # "ssh-ed25519 <key> <name>"
    ];
  };

  # TODO replace this with domain
  networking.domain = "example.org";
  security.acme.acceptTerms = true;

  eilean = {
    # TODO replace these values
    username = "user";
    secretsDir = "/secrets";
    serverIpv4 = "203.0.113.0";
    serverIpv6 = "2001:DB8::/64";
    publicInterface = "eth0";

    # mailserver.enable = true;
    # matrix.enable = true;
    # turn.enable = true;
    # mastodon.enable = true;
    # gitea.enable = true;
    # dns.enable = true;
  };
}
