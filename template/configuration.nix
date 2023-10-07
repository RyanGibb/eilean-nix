{ pkgs, config, lib, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # TODO change system if not running on x84_64
  nixpkgs.hostPlatform.system = "x86_64-linux";

  system.stateVersion = "22.11";

  environment.systemPackages = with pkgs; [
    git # for nix flakes
    vim # for editing config files
  ];

  # very simple prompt
  programs.bash.promptInit = ''
    PS1='\u@\h:\w \$ '
  '';

  users.users = {
    root = {
      # TODO set hashed password from `nix run nixpkgs#mkpasswd`
      initialHashedPassword = "";
    };
    # TODO change username, if desired
    nixos = {
      # TODO set hashed password from `nix run nixpkgs#mkpasswd`
      initialHashedPassword = "";
      openssh.authorizedKeys.keys = [
        # TODO define SSH keys if accessing remotely
        # "ssh-ed25519 <key> <name>"
      ];
    };
  };

  services.openssh = {
    enable = true;
    settings.passwordAuthentication = false;
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

    # TODO enable desired services
    # mailserver.enable = true;
    # matrix.enable = true;
    # turn.enable = true;
    # mastodon.enable = true;
    # gitea.enable = true;
    # dns.enable = true;
  };
}