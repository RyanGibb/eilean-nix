{ pkgs, config, lib, ... }:

let cfg = config.dns; in {
  services.bind = lib.mkIf (cfg.enable && cfg.server == "bind") {
    enable = true;
    # recursive resolver
    # cacheNetworks = [ "0.0.0.0/0" ];
    zones =
      let mapZones = zonename: zone:
        {
          master = true;
          file = import ./zonefile.nix { inherit pkgs config lib zonename zone; };
          # axfr zone transfer
          slaves = [
            "127.0.0.1"
          ];
        };
      in builtins.mapAttrs mapZones cfg.zones;
  };
}
