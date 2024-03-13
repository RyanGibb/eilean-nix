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

    systemd.services = mkIf cfg.matrix.turn {
      matrix-synapse-turn-shared-secret-generator = {
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
      "matrix-synapse" = {
        after = [ "matrix-synapse-turn-shared-secret-generator.service" ];
        requires = [ "matrix-synapse-turn-shared-secret-generator.service" ];
      };
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
