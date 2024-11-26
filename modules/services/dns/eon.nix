{ pkgs, config, lib, ... }:

let cfg = config.eilean.services.dns;
in lib.mkIf (cfg.enable && cfg.server == "eon") {
  services.eon = {
    enable = true;
    application = "capd";
    capnpAddress = lib.mkDefault config.networking.domain;
    zoneFiles = let
      mapZonefile = zonename: zone:
        "${
          import ./zonefile.nix { inherit pkgs config lib zonename zone; }
        }/${zonename}";
    in lib.attrsets.mapAttrsToList mapZonefile cfg.zones;
  };

  users.users = { eon.extraGroups = [ config.services.opendkim.group ]; };

  ### bind prestart copy zonefiles
  systemd.services.eon.postStart = let
    update = ''
      update() {
        local file="$1"
        local domain="$2"
        local input=$(tr -d '\n' < "$file")
        local record_name=$(echo "$input" | ${pkgs.gawk}/bin/awk '{print $1}')
        local record_type=$(echo "$input" | ${pkgs.gawk}/bin/awk '{print $3}')
        local ttl=3600
        local record_value=$(echo "$input" | ${pkgs.gnused}/bin/sed -E 's/[^"]*"([^"]*)"[^"]*/\1/g')
        ${config.services.eon.package}/bin/capc update /var/lib/eon/caps/domain/''${domain}.cap -u add:''${record_name}.''${domain}:''${record_type}:"''${record_value}":''${ttl} || exit 0
      }
      shopt -s nullglob
    '';
    ops = let
      mapZones = zonename: zone: ''
        for f in ${config.mailserver.dkimKeyDirectory}/${zonename}.*.txt; do
          update $f ${zonename}
        done
      '';
    in lib.attrsets.mapAttrsToList mapZones cfg.zones;
  in update + builtins.concatStringsSep "\n" ops;
}
