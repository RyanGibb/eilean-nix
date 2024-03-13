{ pkgs, config, lib, ... }:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
in {
  options.eilean.gitea = {
    enable = mkEnableOption "gitea";
    sshPort = mkOption {
      type = types.int;
      default = 3001;
    };
    databasePasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };
  };

  config = mkIf cfg.gitea.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."git.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${builtins.toString config.services.gitea.settings.server.HTTP_PORT}/";
        };
      };
    };

    users.users.git = {
      description = "Git Service";
      home = config.services.gitea.stateDir;
      useDefaultShell = true;
      group = "gitea";
      isSystemUser = true;
    };

    services.gitea = {
      enable = true;
      user = "git";
      appName = "git | ${domain}";
      mailerPasswordFile = cfg.mailserver.systemAccountPasswordFile;
      settings = {
        server = {
          ROOT_URL = "https://git.${domain}/";
          DOMAIN = "git.${domain}";
        };
        mailer = {
          ENABLED = true;
          FROM = "git@${domain}";
          MAILER_TYPE = "smtp";
          HOST = "mail.${domain}:465";
          USER = "system@${domain}";
          IS_TLS_ENABLED = true;
        };
        repository.DEFAULT_BRANCH = "main";
        service.DISABLE_REGISTRATION = true;
        #server.HTTP_PORT = 3000;
      };
      database = {
        type = "postgres";
        passwordFile = cfg.gitea.databasePasswordFile;
        user = "git";
        name = "git";
        #createDatabase = true;
        #socket = "/run/postgresql";
      };
      #stateDir = "/var/lib/gitea";
    };

    # https://github.com/NixOS/nixpkgs/issues/103446
    systemd.services.gitea.serviceConfig = {
      ReadWritePaths = [ "/var/lib/postfix/queue/maildrop" ];
      NoNewPrivileges = mkForce false;
      PrivateDevices = mkForce false;
      PrivateUsers = mkForce false;
      ProtectHostname = mkForce false;
      ProtectClock = mkForce false;
      ProtectKernelTunables = mkForce false;
      ProtectKernelModules = mkForce false;
      ProtectKernelLogs = mkForce false;
      RestrictAddressFamilies = mkForce [ ];
      LockPersonality = mkForce false;
      MemoryDenyWriteExecute = mkForce false;
      RestrictRealtime = mkForce false;
      RestrictSUIDSGID = mkForce false;
      SystemCallArchitectures = mkForce "";
      SystemCallFilter = mkForce [];
    };

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [
      {
        name = "git";
        type = "CNAME";
        data = "vps";
      }
    ];

    # proxy port 22 on ethernet interface to internal gitea ssh server
    # openssh server remains accessible on port 22 via vpn(s)

    # allow forwarding
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking.firewall = {
      allowedTCPPorts = [
        22
        cfg.gitea.sshPort
      ];
      extraCommands = ''
        # proxy all traffic on public interface to the gitea SSH server
        iptables -A PREROUTING -t nat -i ${config.eilean.publicInterface} -p tcp --dport 22 -j REDIRECT --to-port ${builtins.toString cfg.gitea.sshPort}
        ip6tables -A PREROUTING -t nat -i ${config.eilean.publicInterface} -p tcp --dport 22 -j REDIRECT --to-port ${builtins.toString cfg.gitea.sshPort}

        # proxy locally originating outgoing packets
        iptables -A OUTPUT -d ${config.eilean.serverIpv4} -t nat -p tcp --dport 22 -j REDIRECT --to-port ${builtins.toString cfg.gitea.sshPort}
        ip6tables -A OUTPUT -d ${config.eilean.serverIpv6} -t nat -p tcp --dport 22 -j REDIRECT --to-port ${builtins.toString cfg.gitea.sshPort}
      '';
    };

    services.gitea.settings.server = {
      START_SSH_SERVER = true;
      SSH_LISTEN_PORT = cfg.gitea.sshPort;
    };
  };
}
