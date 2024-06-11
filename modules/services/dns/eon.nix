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
}
