{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
  subdomain = "matrix.${domain}";
  turnDomain = "turn.${domain}";
in {
  options.eilean.matrix = {
    enable = mkEnableOption "matrix";
    registrationSecretFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    call = mkOption {
      type = types.bool;
      default = true;
    };
    livekitKeys = mkOption {
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

    security.acme-eon.nginxCerts = lib.mkIf cfg.acme-eon [ domain subdomain ];

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
        # i.e. to delegate from the host being accessible as ${domain}
        # to another host actually running the Matrix homeserver.
        "${domain}" = {
          enableACME = lib.mkIf (!cfg.acme-eon) true;
          forceSSL = true;

          locations."= /.well-known/matrix/server".extraConfig = let
            # use 443 instead of the default 8448 port to unite
            # the client-server and server-server port for simplicity
            server = { "m.server" = "${subdomain}:443"; };
          in ''
            default_type application/json;
            return 200 '${builtins.toJSON server}';
          '';
          locations."= /.well-known/matrix/client".extraConfig = let
            client = {
              "m.homeserver" = { "base_url" = "https://${subdomain}"; };
              "m.identity_server" = { "base_url" = "https://vector.im"; };
              "org.matrix.msc4143.rtc_foci" = [{
                "type" = "livekit";
                "livekit_service_url" = "https://${subdomain}/livekit/jwt";
              }];
            };
            # ACAO required to allow element-web on any URL to request this json file
            # set other headers due to https://github.com/yandex/gixy/blob/master/docs/en/plugins/addheaderredefinition.md
          in ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization";
            add_header Strict-Transport-Security max-age=31536000 always;
            add_header X-Frame-Options SAMEORIGIN always;
            add_header X-Content-Type-Options nosniff always;
            add_header Content-Security-Policy "default-src 'self'; base-uri 'self'; frame-src 'self'; frame-ancestors 'self'; form-action 'self';" always;
            add_header Referrer-Policy 'same-origin';
            return 200 '${builtins.toJSON client}';
          '';
        };

        # Reverse proxy for Matrix client-server and server-server communication
        "${subdomain}" = {
          enableACME = lib.mkIf (!cfg.acme-eon) true;
          forceSSL = true;

          locations."/".extraConfig = ''
            return 404;
          '';

          # forward all Matrix API calls to the synapse Matrix homeserver
          locations."~ ^(\\/_matrix|\\/_synapse\\/client)" = {
            proxyPass = "http://127.0.0.1:8008";
          };

          locations."^~ /livekit/jwt/" = {
            proxyPass = "http://localhost:8080/";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };

          locations."^~ /livekit/sfu/" = {
            proxyPass = "http://localhost:7880/";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              proxy_send_timeout 120;
              proxy_read_timeout 120;
              proxy_buffering off;

              proxy_set_header Accept-Encoding gzip;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
            '';
          };
        };
      };
    };

    services.matrix-synapse = {
      enable = true;
      settings = mkMerge [
        {
          server_name = domain;
          enable_registration = true;
          registration_requires_token = true;
          registration_shared_secret_path = cfg.matrix.registrationSecretFile;
          listeners = [{
            port = 8008;
            bind_addresses = [ "::1" "127.0.0.1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [{
              names = [ "client" "federation" ];
              compress = false;
            }];
          }];
          max_upload_size = "100M";
          app_service_config_files = (optional cfg.matrix.bridges.instagram
            "/var/lib/mautrix-instagram/instagram-registration.yaml")
            ++ (optional cfg.matrix.bridges.messenger
              "/var/lib/mautrix-messenger/messenger-registration.yaml");
        }
        (mkIf cfg.matrix.call {
          experimental_features = {
            msc3266_enabled = true;
            msc4222_enabled = true;
          };
          max_event_delay_duration = "24h";
          rc_message = {
            per_second = 0.5;
            burst_count = 30;
          };
          rc_delayed_event_mgmt = {
            per_second = 1;
            burst_count = 20;
          };
        })
      ];
    };

    security.acme-eon.certs."${turnDomain}" =
      lib.mkIf (cfg.acme-eon && cfg.matrix.call) {
        reloadServices = [ "livekit" ];
      };
    services.livekit = mkIf cfg.matrix.call {
      enable = true;
      keyFile = cfg.matrix.livekitKeys;
      settings = {
        turn = {
          enabled = true;
          tls_port = 5349;
          udp_port = 5349;
          domain = turnDomain;
          cert_file = "/run/credentials/livekit.service/turn-cert";
          key_file = "/run/credentials/livekit.service/turn-key";
        };
      };
    };
    systemd.services.livekit.serviceConfig = let
      certDir = if cfg.acme-eon then
        config.security.acme-eon.certs.${turnDomain}.directory
      else
        config.security.acme.certs.${turnDomain}.directory;
    in lib.mkIf cfg.matrix.call {
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      LoadCredential =
        [ "turn-cert:${certDir}/fullchain.pem" "turn-key:${certDir}/key.pem" ];
    };

    services.lk-jwt-service = mkIf cfg.matrix.call {
      enable = true;
      livekitUrl = "wss://${subdomain}/livekit/sfu";
      keyFile = config.services.livekit.keyFile;
    };

    systemd.services.matrix-synapse.serviceConfig.SupplementaryGroups =
      # remove after https://github.com/NixOS/nixpkgs/pull/311681/files
      (optional cfg.matrix.bridges.whatsapp
        config.systemd.services.mautrix-whatsapp.serviceConfig.Group)
      ++ (optional cfg.matrix.bridges.instagram
        config.systemd.services.mautrix-instagram.serviceConfig.Group)
      ++ (optional cfg.matrix.bridges.messenger
        config.systemd.services.mautrix-messenger.serviceConfig.Group);

    services.mautrix-whatsapp = mkIf cfg.matrix.bridges.whatsapp {
      enable = true;
      settings.homeserver.address = "https://${subdomain}";
      settings.homeserver.domain = domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29318";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.history_sync.backfill = false;
      settings.bridge.permissions."@${config.eilean.username}:${domain}" =
        "admin";
      settings.bridge.encryption.allow = true;
      settings.bridge.encryption.default = true;
    };
    # using https://github.com/NixOS/nixpkgs/pull/277368
    services.mautrix-signal = mkIf cfg.matrix.bridges.signal {
      enable = true;
      settings.homeserver.address = "https://${subdomain}";
      settings.homeserver.domain = domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29328";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.permissions."@${config.eilean.username}:${domain}" =
        "admin";
      settings.bridge.encryption.allow = true;
      settings.bridge.encryption.default = true;
    };
    # TODO replace with upstreamed mautrix-meta
    services.mautrix-instagram = mkIf cfg.matrix.bridges.instagram {
      enable = true;
      settings.homeserver.address = "https://${subdomain}";
      settings.homeserver.domain = domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29319";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.backfill.enabled = false;
      settings.bridge.permissions."@${config.eilean.username}:${domain}" =
        "admin";
      settings.bridge.encryption.allow = true;
      settings.bridge.encryption.default = true;
    };
    services.mautrix-messenger = mkIf cfg.matrix.bridges.messenger {
      enable = true;
      settings.homeserver.address = "https://${subdomain}";
      settings.homeserver.domain = domain;
      settings.appservice.hostname = "localhost";
      settings.appservice.address = "http://localhost:29320";
      settings.bridge.personal_filtering_spaces = true;
      settings.bridge.backfill.enabled = false;
      settings.bridge.permissions."@${config.eilean.username}:${domain}" =
        "admin";
      settings.bridge.encryption.allow = true;
      settings.bridge.encryption.default = true;
    };

    eilean.dns.enable = true;
    eilean.services.dns.zones.${domain}.records = [{
      name = "matrix";
      type = "CNAME";
      value = cfg.domainName;
    }] ++ lib.optional cfg.matrix.call {
      name = "turn";
      type = "CNAME";
      value = cfg.domainName;
    };
  };
}
