{ config, lib, ... }:

with lib;
let cfg = config.eilean;
in {

  options.eilean.dns = {
    enable = mkEnableOption "dns";
    nameservers = mkOption {
      type = types.listOf types.str;
      default = [ "ns1" "ns2" ];
    };
  };

  config.eilean.services.dns = mkIf cfg.dns.enable {
    enable = true;
    zones.${config.networking.domain} = {
      soa.serial = mkDefault 0;
      records = builtins.concatMap (ns: [
        {
          name = "@";
          type = "NS";
          value = ns;
        }
        {
          name = ns;
          type = "A";
          value = cfg.serverIpv4;
        }
        {
          name = ns;
          type = "AAAA";
          value = cfg.serverIpv6;
        }
      ]) cfg.dns.nameservers ++ [
        {
          name = "@";
          type = "A";
          value = cfg.serverIpv4;
        }
        {
          name = "@";
          type = "AAAA";
          value = cfg.serverIpv6;
        }

        {
          name = cfg.domainName;
          type = "A";
          value = cfg.serverIpv4;
        }
        {
          name = cfg.domainName;
          type = "AAAA";
          value = cfg.serverIpv6;
        }

        {
          name = "@";
          type = "LOC";
          value = "52 12 40.4 N 0 5 31.9 E 22m 10m 10m 10m";
        }
      ];
    };
  };
}
