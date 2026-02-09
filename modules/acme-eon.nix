{
  pkgs,
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.eilean;
in
{
  options.eilean.acme-eon = mkEnableOption "acme-eon";

  config = mkIf cfg.acme-eon {
    assertions = [
      {
        assertion = cfg.services.dns.server == "eon";
        message = ''
          If config.eilean.acme-eon is enabled config.eilean.services.dns.server must be "eon".
        '';
      }
    ];
  };
}
