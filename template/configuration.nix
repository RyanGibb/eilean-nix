{ pkgs, config, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git # for nix flakes
    vim # for editing config files
    # TODO add any other programs you want to install here
  ];

  # very simple prompt
  programs.bash.promptInit = ''
    PS1='\u@\h:\w \$ '
  '';

  users.users = rec {
    # TODO set hashed password from `nix run nixpkgs#mkpasswd`
    root.initialHashedPassword = "";
    # TODO change username, if desired
    eilean = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      initialHashedPassword = root.initialHashedPassword;
      # TODO define SSH keys if accessing remotely
      openssh.authorizedKeys.keys = [
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

  # TODO select internationalisation properties
  i18n.defaultLocale = "en_GB.UTF-8";
  time.timeZone = "Europe/London";
  console.keyMap = "uk";

  eilean = {
    # TODO replace these values
    username = "user";
    secretsDir = "/secrets";
    serverIpv4 = "203.0.113.0";
    serverIpv6 = "2001:DB8:0:0:0:0:0:0";
    publicInterface = "enp1s0";

    # TODO enable desired services
    dns.enable = true;
    # mailserver.enable = true;
    # matrix.enable = true;
    # mastodon.enable = true;
    # gitea.enable = true;
    # dns.enable = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}