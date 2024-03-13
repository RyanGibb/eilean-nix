{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.mautrix-instagram;
  dataDir = "/var/lib/mautrix-instagram";
  registrationFile = "${dataDir}/instagram-registration.yaml";
  settingsFile = "${dataDir}/config.json";
  settingsFileUnsubstituted = settingsFormat.generate "mautrix-instagram-config-unsubstituted.json" cfg.settings;
  settingsFormat = pkgs.formats.json {};
  appservicePort = 29319;

  mkDefaults = lib.mapAttrsRecursive (n: v: lib.mkDefault v);
  defaultConfig = {
    homeserver.address = "http://localhost:8448";
    meta.mode = "instagram";
    appservice = {
      hostname = "[::]";
      port = appservicePort;
      database.type = "sqlite3";
      database.uri = "${dataDir}/mautrix-instagram.db";
      id = "instagram";
      bot.username = "instagrambot";
      bot.displayname = "Instagram Bridge Bot";
      bot.avatar = "mxc://maunium.net/JxjlbZUlCPULEeHZSwleUXQv";
      as_token = "";
      hs_token = "";
    };
    bridge = {
      username_template = "instagram_{{.}}";
      double_puppet_server_map = {};
      login_shared_secret_map = {};
      permissions."*" = "relay";
      relay.enabled = true;
    };
    logging = {
      min_level = "info";
      writers = lib.singleton {
        type = "stdout";
        format = "pretty-colored";
        time_format = " ";
      };
    };
  };

in {
  options.services.mautrix-instagram = {
    enable = lib.mkEnableOption (lib.mdDoc "mautrix-instagram, a puppeting/relaybot bridge between Matrix and Instagram.");

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = defaultConfig;
      description = lib.mdDoc ''
        {file}`config.yaml` configuration as a Nix attribute set.
        Configuration options should match those described in
        [example-config.yaml](https://github.com/mautrix/instagram/blob/master/example-config.yaml).
      '';
      example = {
        appservice = {
          database = {
            type = "postgres";
            uri = "postgresql:///mautrix_instagram?host=/run/postgresql";
          };
          id = "instagram";
          ephemeral_events = false;
        };
        bridge = {
          history_sync = {
            request_full_sync = true;
          };
          private_chat_portal_meta = true;
          mute_bridging = true;
          encryption = {
            allow = true;
            default = true;
            require = true;
          };
          provisioning = {
            shared_secret = "disable";
          };
          permissions = {
            "example.com" = "user";
          };
        };
      };
    };

    serviceDependencies = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.optional config.services.matrix-synapse.enable config.services.matrix-synapse.serviceUnit;
      defaultText = lib.literalExpression ''
        optional config.services.matrix-synapse.enable config.services.matrix-synapse.serviceUnits
      '';
      description = lib.mdDoc ''
        List of Systemd services to require and wait for when starting the application service.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    users.users.mautrix-instagram = {
      isSystemUser = true;
      group = "mautrix-instagram";
      home = dataDir;
      description = "Mautrix-Instagram bridge user";
    };

    users.groups.mautrix-instagram = {};

    services.mautrix-instagram.settings = lib.mkMerge (map mkDefaults [
      defaultConfig
      # Note: this is defined here to avoid the docs depending on `config`
      { homeserver.domain = config.services.matrix-synapse.settings.server_name; }
    ]);

    systemd.services.mautrix-instagram = {
      description = "Mautrix-Instagram Service - A Instagram bridge for Matrix";

      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"] ++ cfg.serviceDependencies;
      after = ["network-online.target"] ++ cfg.serviceDependencies;

      preStart = ''
        # substitute the settings file by environment variables
        # in this case read from EnvironmentFile
        test -f '${settingsFile}' && rm -f '${settingsFile}'
        old_umask=$(umask)
        umask 0177
        ${pkgs.envsubst}/bin/envsubst \
          -o '${settingsFile}' \
          -i '${settingsFileUnsubstituted}'
        umask $old_umask

        # generate the appservice's registration file if absent
        if [ ! -f '${registrationFile}' ]; then
          ${pkgs.mautrix-meta}/bin/mautrix-meta \
            --generate-registration \
            --config='${settingsFile}' \
            --registration='${registrationFile}'
        fi
        chmod 640 ${registrationFile}

        umask 0177
        ${pkgs.yq}/bin/yq -s '.[0].appservice.as_token = .[1].as_token
          | .[0].appservice.hs_token = .[1].hs_token
          | .[0]' '${settingsFile}' '${registrationFile}' \
          > '${settingsFile}.tmp'
        mv '${settingsFile}.tmp' '${settingsFile}'
        umask $old_umask
      '';

      serviceConfig = {
        User = "mautrix-instagram";
        Group = "mautrix-instagram";
        StateDirectory = baseNameOf dataDir;
        WorkingDirectory = dataDir;
        ExecStart = ''
          ${pkgs.mautrix-meta}/bin/mautrix-meta \
          --config='${settingsFile}' \
          --registration='${registrationFile}'
        '';
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        Restart = "on-failure";
        RestartSec = "30s";
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = ["@system-service"];
        Type = "simple";
        UMask = 0027;
      };
      restartTriggers = [settingsFileUnsubstituted];
    };
  };
}
