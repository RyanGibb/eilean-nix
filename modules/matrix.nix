{ config, pkgs, lib, ... }:

let cfg = config.eilean; in
{
  options.eilean.matrix = {
    enable = lib.mkEnableOption "matrix";
    turn = lib.mkOption {
      type = lib.types.bool;
      default = cfg.turn.enable;
    };
  };

  config = lib.mkIf cfg.matrix.enable {
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
              add_header Content-Type application/json;
              return 200 '${builtins.toJSON server}';
            '';
          locations."= /.well-known/matrix/client".extraConfig =
            let
              client = {
                "m.homeserver" =  { "base_url" = "https://matrix.${config.networking.domain}"; };
                "m.identity_server" =  { "base_url" = "https://vector.im"; };
              };
            # ACAO required to allow element-web on any URL to request this json file
            in ''
              add_header Content-Type application/json;
              add_header Access-Control-Allow-Origin *;
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
      settings = lib.mkMerge [
        {
          server_name = config.networking.domain;
          enable_registration = true;
          registration_requires_token = true;
          auto_join_rooms = [ "#freumh:freumh.org" ];
          registration_shared_secret_path = "${config.eilean.secretsDir}/matrix-shared-secret";
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
        (lib.mkIf cfg.matrix.turn {
          turn_uris = with config.services.coturn; [
            "turn:${realm}:3478?transport=udp"
            "turn:${realm}:3478?transport=tcp"
            "turns:${realm}:5349?transport=udp"
            "turns:${realm}:5349?transport=tcp"
          ];
          turn_user_lifetime = "1h";
        })
      ];
      extraConfigFiles = [ "${config.eilean.secretsDir}/matrix-turn-shared-secret" ];
    };

    dns.zones.${config.networking.domain}.records = [
      {
        name = "matrix";
        type = "CNAME";
        data = "vps";
      }
    ];
  };
}
