{ pkgs, config, lib, ... }:

with lib;

let cfg = config.wireguard; in
{
  options.wireguard = {
    enable = mkEnableOption "wireguard";
    server = mkOption {
      type = with types; bool;
      default = cfg.hosts.${config.networking.hostName}.server;
    };
    hosts =
      let hostOps = { ... }: {
        options = {
          ip = mkOption {
            type = types.str;
          };
          publicKey = mkOption {
            type = types.str;
          };
          server = mkOption {
            type = types.bool;
            default = false;
          };
          endpoint = mkOption {
            type = with types; nullOr str;
            default = null;
            # should not be null when server = true
          };
          persistentKeepalive = mkOption {
            type = with types; nullOr int;
            default = null;
          };
        };
      };
      in mkOption {
        type = with types; attrsOf (submodule hostOps);
      };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ wireguard-tools ];
    networking = {
      # populate /etc/hosts with hostnames and IPs
      extraHosts = builtins.concatStringsSep "\n" (
        attrsets.mapAttrsToList (
          hostName: values: "${values.ip} ${hostName}"
        ) cfg.hosts
      );

      firewall = {
        allowedUDPPorts = [ 51820 ];
        checkReversePath = false;
      };

      wireguard = {
        enable = true;
        interfaces.wg0 = let hostName = config.networking.hostName; in {
          ips = [ "${cfg.hosts."${hostName}".ip}/24" ];
          listenPort = 51820;
          privateKeyFile = "${config.custom.secretsDir}/wireguard-key-${hostName}";
          peers =
            let
              serverPeers = attrsets.mapAttrsToList
                (hostName: values:
                  if values.server then
                  {
                    allowedIPs = [ "10.0.0.0/24" ];
                    publicKey = values.publicKey;
                    endpoint = "${values.endpoint}:51820";
                    persistentKeepalive = values.persistentKeepalive;
                  }
                else {})
                cfg.hosts;
              # remove empty elements
              cleanedServerPeers = lists.remove { } serverPeers;
            in mkIf (!cfg.server) cleanedServerPeers; 
        };
      };
    };
  };
}
