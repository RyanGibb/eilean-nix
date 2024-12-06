{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.eilean;
in {
  options.eilean.fail2ban = {
    enable = mkEnableOption "TURN server";
    radicale = mkOption {
      type = types.bool;
      default = cfg.radicale.enable;
    };
  };

  config = mkIf cfg.fail2ban.enable {
    services.fail2ban = {
      enable = true;
      bantime = "24h";
      bantime-increment = {
        enable = true;
        multipliers = "1 2 4 8 16 32 64";
        maxtime = "168h";
        overalljails = true;
      };
      jails."radicale".settings = mkIf cfg.fail2ban.radicale {
        port = "5232";
        filter = "radicale";
        banaction = "%(banaction_allports)s[name=radicale]";
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=radicale.service";
        maxRetry = 2;
        bantime = -1;
        findtime = 14400;
      };
    };
    environment.etc = {
      "fail2ban/filter.d/radicale.local".text = mkIf cfg.fail2ban.radicale ''
        [Definition]
        failregex = ^.*Failed\slogin\sattempt\sfrom\s.*\(forwarded for \'<HOST>\'.*\):\s.*
      '';
    };
  };
}
