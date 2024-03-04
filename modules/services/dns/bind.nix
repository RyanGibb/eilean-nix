{ pkgs, config, lib, ... }:

let cfg = config.eilean.services.dns; in
lib.mkIf (cfg.enable && cfg.server == "bind") {
  services.bind = {
    enable = true;
    # recursive resolver
    # cacheNetworks = [ "0.0.0.0/0" ];
    zones =
      let mapZones = zonename: zone:
        {
          master = true;
          file = "${config.services.bind.directory}/${zonename}";
          #file = "${import ./zonefile.nix { inherit pkgs config lib zonename zone; }}/${zonename}";
          # axfr zone transfer
          slaves = [
            "127.0.0.1"
          ];
        };
      in builtins.mapAttrs mapZones cfg.zones;
  };

  ### bind prestart copy zonefiles
  systemd.services.bind.preStart =
    let ops =
      let mapZones = zonename: zone:
        let
          zonefile = "${import ./zonefile.nix { inherit pkgs config lib zonename zone; }}/${zonename}";
          path = "${config.services.bind.directory}/${zonename}";
        in ''
          if ! diff ${zonefile} ${path} > /dev/null; then
            cp ${zonefile} ${path}
            # remove journal file to avoid 'journal out of sync with zone'
            # NB this will reset dynamic updates
            rm -f ${path}.signed.jnl
          fi
        '';
      in lib.attrsets.mapAttrsToList mapZones cfg.zones;
    in builtins.concatStringsSep "\n" ops;
}
