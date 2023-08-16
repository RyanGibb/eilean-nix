{ pkgs, config, lib, ... }:

with lib;

let
  zoneOptions.options = {
    ttl = mkOption {
      type = types.int;
      default = 3600; # 1hr
    };
    soa = {
      ns = mkOption {
        type = types.str;
        default = "ns1";
      };
      email = mkOption {
        type = types.str;
        default = "dns";
      };
      # TODO auto increment
      serial = mkOption {
        type = types.int;
      };
      refresh = mkOption {
        type = types.int;
        default = 3600; # 1hr
      };
      retry = mkOption {
        type = types.int;
        default = 900; # 15m
      };
      expire = mkOption {
        type = types.int;
        default = 1814400; # 21d
      };
      negativeCacheTtl = mkOption {
        type = types.int;
        default = 3600; # 1hr
      };
    };
    records =
      let recordOpts.options = {
        name = mkOption {
          type = types.str;
        };
        ttl = mkOption {
          type = with types; nullOr int;
          default = null;
        };
        type = mkOption {
          type = types.str;
        };
        data = mkOption {
          type = types.str;
        };
      };
      in mkOption {
        type = with types; listOf (submodule recordOpts);
        default = [ ];
      };
  };
in
{
  imports = [ ./bind.nix ];

  options.dns = {
    enable = lib.mkEnableOption "DNS server";
    server = mkOption {
      type = types.enum [ "bind" ];
      default = "bind";
    };
    openFirewall = mkOption {
      type = types.bool;
      default = true;
    };
    zones = mkOption {
      type = with types; attrsOf (submodule zoneOptions);
    };
  };

  config.networking.firewall = lib.mkIf config.dns.openFirewall {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
