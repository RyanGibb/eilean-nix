{
  pkgs,
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.eilean;
  domain = config.networking.domain;
  passwdDir = "/var/lib/radicale/users";
  passwdFile = "${passwdDir}/passwd";
  userOps =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          readOnly = true;
          default = name;
        };
        passwordFile = mkOption { type = types.nullOr types.str; };
      };
    };
in
{
  options.eilean.radicale = {
    enable = mkEnableOption "radicale";
    users = mkOption {
      type = with types; nullOr (attrsOf (submodule userOps));
      default = { };
    };
  };

  config = mkIf cfg.radicale.enable {
    services.radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [ "0.0.0.0:5232" ];
        };
        auth = {
          type = "htpasswd";
          htpasswd_filename = passwdFile;
          htpasswd_encryption = "bcrypt";
        };
        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
        };
      };
    };

    systemd.services.radicale = {
      serviceConfig.ReadWritePaths = [ "/var/lib/radicale" ];
      preStart = lib.mkIf (cfg.radicale.users != null) ''
        if (! test -d "${passwdDir}"); then
          mkdir "${passwdDir}"
          chmod 755 "${passwdDir}"
        fi

        umask 077

        cat <<EOF > ${passwdFile}

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value:
            ''$(${pkgs.apacheHttpd}/bin/htpasswd -nbB "${name}" "$(head -n 2 ${value.passwordFile})")''
          ) cfg.radicale.users
        )}
        EOF
      '';
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "cal.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://localhost:5232";
          };
        };
      };
    };

    eilean.dns.enable = true;
    eilean.services.dns.zones.${domain}.records = [
      {
        name = "cal";
        type = "CNAME";
        value = cfg.domainName;
      }
    ];
  };
}
