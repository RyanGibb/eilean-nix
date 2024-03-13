{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.eilean;
  turnSharedSecretFile = "/run/matrix-synapse/turn-shared-secret";
in
{
  options.eilean.matrix = {
    enable = mkEnableOption "matrix";
    turn = mkOption {
      type = types.bool;
      default = true;
    };
    registrationSecretFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    bridges = {
      whatsapp = mkOption {
        type = types.bool;
        default = false;
        description = "Enable WhatsApp bridge.";
      };
      signal = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Signal bridge.";
      };
      instagram = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Instagram bridge.";
      };
      messenger = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Facebook Messenger bridge.";
      };
    };
  };

  config = mkIf cfg.matrix.enable {
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql_13;
    services.postgresql.initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';

    services.nginx = {
      enable = true;
      # only recommendedProxySettings and recommendedGzipSettings are strictly required,
      # but the rest make sense as well
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        # This host section can be placed on a different host than the rest,
        # i.e. to delegate from the host being accessible as ${config.networking.domain}
        # to another host actually running the Matrix homeserver.
        "${config.networking.domain}" = {
          enableACME = true;
          forceSSL = true;

          locations."= /.well-known/matrix/server".extraConfig =
            let
              # use 443 instead of the default 8448 port to unite
              # the client-server and server-server port for simplicity
              server = { "m.server" = "matrix.${config.networking.domain}:443"; };
            in ''
              default_type application/json;
              return 200 '${builtins.toJSON server}';
            '';
          locations."= /.well-known/matrix/client".extraConfig =
            let
              client = {
                "m.homeserver" =  { "base_url" = "https://matrix.${config.networking.domain}"; };
                "m.identity_server" =  { "base_url" = "https://vector.im"; };
              };
            # ACAO required to allow element-web on any URL to request this json file
            # set other headers due to https://github.com/yandex/gixy/blob/master/docs/en/plugins/addheaderredefinition.md
            in ''
              default_type application/json;
              add_header Access-Control-Allow-Origin *;
              add_header Strict-Transport-Security max-age=31536000 always;
              add_header X-Frame-Options SAMEORIGIN always;
              add_header X-Content-Type-Options nosniff always;
              add_header Content-Security-Policy "default-src 'self'; base-uri 'self'; frame-src 'self'; frame-ancestors 'self'; form-action 'self';" always;
              add_header Referrer-Policy 'same-origin';
              return 200 '${builtins.toJSON client}';
            '';
        };

        # Reverse proxy for Matrix client-server and server-server communication
        "matrix.${config.networking.domain}" = {
          enableACME = true;
          forceSSL = true;

          # Or do a redirect instead of the 404, or whatever is appropriate for you.
          # But do not put a Matrix Web client here! See the Element web section below.
          locations."/".extraConfig = ''
            return 404;
          '';

          # forward all Matrix API calls to the synapse Matrix homeserver
          locations."/_matrix" = {
            proxyPass = "http://127.0.0.1:8008"; # without a trailing /
            #proxyPassReverse = "http://127.0.0.1:8008"; # without a trailing /
          };
        };
      };
    };

    services.matrix-synapse = {
      enable = true;
      settings = mkMerge [
        {
          server_name = config.networking.domain;
          enable_registration = true;
          registration_requires_token = true;
          registration_shared_secret_path = cfg.matrix.registrationSecretFile;
          listeners = [
            {
              port = 8008;
              bind_addresses = [ "::1" "127.0.0.1" ];
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
                  names = [ "client" "federation" ];
                  compress = false;
                }
              ];
            }
          ];
          max_upload_size = "100M";
          app_service_config_files =
            (optional cfg.matrix.bridges.whatsapp "/var/lib/mautrix-whatsapp/whatsapp-registration.yaml") ++
            (optional cfg.matrix.bridges.signal "/var/lib/mautrix-signal/signal-registration.yaml") ++
            (optional cfg.matrix.bridges.instagram "/var/lib/mautrix-instagram/instagram-registration.yaml") ++
            (optional cfg.matrix.bridges.messenger "/var/lib/mautrix-messenger/messenger-registration.yaml");
        }
        (mkIf cfg.matrix.turn {
          turn_uris = with config.services.coturn; [
            "turn:${realm}:3478?transport=udp"
            "turn:${realm}:3478?transport=tcp"
            "turns:${realm}:5349?transport=udp"
            "turns:${realm}:5349?transport=tcp"
          ];
          turn_user_lifetime = "1h";
        })
      ];
      extraConfigFiles = mkIf cfg.matrix.turn (
        [ turnSharedSecretFile ]
      );
    };

    systemd.services.matrix-synapse-turn-shared-secret-generator = mkIf cfg.matrix.turn {
      description = "Generate matrix synapse turn shared secret config file";
      script = ''
        mkdir -p "$(dirname '${turnSharedSecretFile}')"
        echo "turn_shared_secret: $(cat '${config.services.coturn.static-auth-secret-file}')" > '${turnSharedSecretFile}'
        chmod 770 '${turnSharedSecretFile}'
        chown ${config.systemd.services.matrix-synapse.serviceConfig.User}:${config.systemd.services.matrix-synapse.serviceConfig.Group} '${turnSharedSecretFile}'
        '';
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      after = [ "coturn-static-auth-secret-generator.service" ];
      requires = [ "coturn-static-auth-secret-generator.service" ];
    };
    systemd.services."matrix-synapse".after = mkIf cfg.matrix.turn [ "matrix-synapse-turn-shared-secret-generator.service" ];
    systemd.services."matrix-synapse".requires = mkIf cfg.matrix.turn [ "matrix-synapse-turn-shared-secret-generator.service" ];

    systemd.services.matrix-synapse.serviceConfig.SupplementaryGroups =
      (optional cfg.matrix.bridges.whatsapp config.systemd.services.mautrix-whatsapp.serviceConfig.Group) ++
      (optional cfg.matrix.bridges.signal config.systemd.services.mautrix-signal.serviceConfig.Group) ++
      (optional cfg.matrix.bridges.instagram config.systemd.services.mautrix-instagram.serviceConfig.Group) ++
      (optional cfg.matrix.bridges.messenger config.systemd.services.mautrix-messenger.serviceConfig.Group);

    services.mautrix-whatsapp = mkIf cfg.matrix.bridges.whatsapp {
      enable = true;
      settings.homeserver.address = "https://matrix.${config.networking.domain}";
      settings.homeserver.domain = config.networking.domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29318";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.history_sync.backfill = false;
      settings.bridge.permissions."@${config.eilean.username}:${config.networking.domain}" = "admin";
    };
    services.mautrix-signal = mkIf cfg.matrix.bridges.signal {
      enable = true;
      settings.homeserver.address = "https://matrix.${config.networking.domain}";
      settings.homeserver.domain = config.networking.domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29328";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.permissions."@${config.eilean.username}:${config.networking.domain}" = "admin";
    };
    services.mautrix-instagram = mkIf cfg.matrix.bridges.instagram {
      enable = true;
      settings.homeserver.address = "https://matrix.${config.networking.domain}";
      settings.homeserver.domain = config.networking.domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29319";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.backfill.enabled = false;
      settings.bridge.permissions."@${config.eilean.username}:${config.networking.domain}" = "admin";
    };
    services.mautrix-messenger = mkIf cfg.matrix.bridges.messenger {
      enable = true;
      settings.homeserver.address = "https://matrix.${config.networking.domain}";
      settings.homeserver.domain = config.networking.domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29320";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.backfill.enabled = false;
      settings.bridge.permissions."@${config.eilean.username}:${config.networking.domain}" = "admin";
    };

    eilean.turn.enable = mkIf cfg.matrix.turn true;

    eilean.dns.enable = true;
    eilean.services.dns.zones.${config.networking.domain}.records = [
      {
        name = "matrix";
        type = "CNAME";
        data = "vps";
      }
    ];
  };
}
