{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.mautrix-messenger;
  dataDir = "/var/lib/mautrix-messenger";
  registrationFile = "${dataDir}/messenger-registration.yaml";
  settingsFile = "${dataDir}/config.json";
  settingsFileUnsubstituted = settingsFormat.generate "mautrix-messenger-config-unsubstituted.json" cfg.settings;
  settingsFormat = pkgs.formats.json {};
  appservicePort = 29320;

  mkDefaults = lib.mapAttrsRecursive (n: v: lib.mkDefault v);
  defaultConfig = {
    homeserver.address = "http://localhost:8448";
    meta.mode = "messenger";
    appservice = {
      hostname = "[::]";
      port = appservicePort;
      database.type = "sqlite3";
      database.uri = "${dataDir}/mautrix-messenger.db";
      id = "messenger";
      bot.username = "messengerbot";
      bot.displayname = "Messenger Bridge Bot";
      as_token = "";
      hs_token = "";
      avatar = "mxc://maunium.net/ygtkteZsXnGJLJHRchUwYWak";
    };
    bridge = {
      username_template = "messenger_{{.}}";
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
  options.services.mautrix-messenger = {
    enable = lib.mkEnableOption (lib.mdDoc "mautrix-messenger, a puppeting/relaybot bridge between Matrix and Messenger.");

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = defaultConfig;
      description = lib.mdDoc ''
        {file}`config.yaml` configuration as a Nix attribute set.
        Configuration options should match those described in
        [example-config.yaml](https://github.com/mautrix/messenger/blob/master/example-config.yaml).
      '';
      example = {
        appservice = {
          database = {
            type = "postgres";
            uri = "postgresql:///mautrix_messenger?host=/run/postgresql";
          };
          id = "messenger";
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

    users.users.mautrix-messenger = {
      isSystemUser = true;
      group = "mautrix-messenger";
      home = dataDir;
      description = "Mautrix-Messenger bridge user";
    };

    users.groups.mautrix-messenger = {};

    services.mautrix-messenger.settings = lib.mkMerge (map mkDefaults [
      defaultConfig
      # Note: this is defined here to avoid the docs depending on `config`
      { homeserver.domain = config.services.matrix-synapse.settings.server_name; }
    ]);

    systemd.services.mautrix-messenger = {
      description = "Mautrix-Messenger Service - A Messenger bridge for Matrix";

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
        User = "mautrix-messenger";
        Group = "mautrix-messenger";
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
