{ pkgs, config, lib, ... }:

let
  cfg = config.hosting;
  domain = config.networking.domain;
in {
  options.hosting.gitea.enable = lib.mkEnableOption "gitea";

  config = lib.mkIf cfg.gitea.enable {
    services.nginx = {
      recommendedProxySettings = true;
      virtualHosts."git.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${builtins.toString config.services.gitea.httpPort}/";
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
      domain = "git.${domain}";
      rootUrl = "https://git.${domain}/";
      mailerPasswordFile = "${config.custom.secretsDir}/email-pswd-unhashed";
      settings = {
        mailer = {
          ENABLED = true;
          FROM = "git@${domain}";
          MAILER_TYPE = "smtp";
          HOST = "mail.${domain}:465";
          USER = "misc@${domain}";
          IS_TLS_ENABLED = true;
        };
        repository.DEFAULT_BRANCH = "main";
        service.DISABLE_REGISTRATION = true;
      };
      database = {
        type = "postgres";
        passwordFile = "${config.custom.secretsDir}/gitea-db";
        user = "git";
        name = "git";
        #createDatabase = true;
        #socket = "/run/postgresql";
      };
      #httpPort = 3000;
      #stateDir = "/var/lib/gitea";
    };

    # https://github.com/NixOS/nixpkgs/issues/103446
    systemd.services.gitea.serviceConfig = {
      ReadWritePaths = [ "/var/lib/postfix/queue/maildrop" ];
      NoNewPrivileges = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      ProtectHostname = lib.mkForce false;
      ProtectClock = lib.mkForce false;
      ProtectKernelTunables = lib.mkForce false;
      ProtectKernelModules = lib.mkForce false;
      ProtectKernelLogs = lib.mkForce false;
      RestrictAddressFamilies = lib.mkForce [ ];
      LockPersonality = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
      RestrictRealtime = lib.mkForce false;
      RestrictSUIDSGID = lib.mkForce false;
      SystemCallArchitectures = lib.mkForce "";
      SystemCallFilter = lib.mkForce [];
    };

    dns.records = [
      {
        name = "git";
        type = "CNAME";
        data = "vps";
      }
    ];
  };
}
