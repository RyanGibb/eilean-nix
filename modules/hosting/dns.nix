{ config, lib, ... }:

let cfg = config.hosting; in
{
  options.hosting.dns.enable = lib.mkEnableOption "dns";
  
  config.dns = lib.mkIf cfg.dns.enable {
    enable = true;
    soa.serial = 2018011623;
    records = builtins.concatMap (ns: [
      {
        name = "@";
        type = "NS";
        data = ns;
      }
      {
        name = ns;
        type = "A";
        data = config.hosting.serverIpv4;
      }
    ]) [ "ns1" "ns2" ] ++
    [
      {
        name = "www";
        type = "CNAME";
        data = "@";
      }

      {
        name = "@";
        type = "A";
        data = config.hosting.serverIpv4;
      }
      {
        name = "@";
        type = "AAAA";
        data = config.hosting.serverIpv6;
      }

      {
        name = "vps";
        type = "A";
        data = config.hosting.serverIpv4;
      }
      {
        name = "vps";
        type = "AAAA";
        data = config.hosting.serverIpv6;
      }
      
      {
        name = "@";
        type = "LOC";
        data = "52 12 40.4 N 0 5 31.9 E 22m 10m 10m 10m";
      }
    ];
  };
}
