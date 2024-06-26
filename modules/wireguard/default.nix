{ pkgs, config, lib, ... }:

with lib;
let cfg = config.wireguard;
in {
  options.wireguard = {
    enable = mkEnableOption "wireguard";
    server = mkOption {
      type = with types; bool;
      default = if cfg.hosts ? config.networking.hostName then
        cfg.hosts.${config.networking.hostName}.server
      else
        false;
    };
    hosts = let
      hostOps = { ... }: {
        options = {
          ip = mkOption { type = types.str; };
          publicKey = mkOption { type = types.str; };
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
          privateKeyFile = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
      };
    in mkOption {
      type = with types; attrsOf (submodule hostOps);
      default = { };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ wireguard-tools ];
    networking = mkMerge [
      {
        # populate /etc/hosts with hostnames and IPs
        extraHosts = builtins.concatStringsSep "\n" (attrsets.mapAttrsToList
          (hostName: values: "${values.ip} ${hostName}") cfg.hosts);

        firewall = {
          allowedUDPPorts = [ 51820 ];
          checkReversePath = false;
        };

        wireguard = {
          enable = true;
          interfaces.wg0 = let hostName = config.networking.hostName;
          in {
            ips = if cfg.hosts ? hostname then
              [ "${cfg.hosts."${hostName}".ip}/24" ]
            else
              [ ];
            listenPort = 51820;
            privateKeyFile = cfg.hosts."${hostName}".privateKeyFile;
            peers = let
              serverPeers = attrsets.mapAttrsToList (hostName: values:
                if values.server then {
                  allowedIPs = [ "10.0.0.0/24" ];
                  publicKey = values.publicKey;
                  endpoint = "${values.endpoint}:51820";
                  persistentKeepalive = values.persistentKeepalive;
                } else
                  { }) cfg.hosts;
              # remove empty elements
              cleanedServerPeers = lists.remove { } serverPeers;
            in mkIf (!cfg.server) cleanedServerPeers;
          };
        };
      }

      (mkIf cfg.server {
        nat = {
          enable = true;
          externalInterface = "enp1s0";
          internalInterfaces = [ "wg0" ];
        };
        firewall = {
          extraCommands = ''
            iptables -I FORWARD -i wg0 -o wg0 -j ACCEPT
          '';
          trustedInterfaces = [ "wg0" ];
        };

        wireguard.interfaces.wg0 = {
          # Route from wireguard to public internet, allowing server to act as VPN
          postSetup = ''
            ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE
          '';

          postShutdown = ''
            ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o enp1s0 -j MASQUERADE
          '';

          # add clients
          peers = with lib.attrsets;
            mapAttrsToList (hostName: values: {
              allowedIPs = [ "${values.ip}/32" ];
              publicKey = values.publicKey;
              persistentKeepalive = values.persistentKeepalive;
            }) cfg.hosts;
        };
      })
    ];
  };
}
