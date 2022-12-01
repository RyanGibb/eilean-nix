{ config, lib, ... }:
{
  mailserver.policydSPFExtraConfig = lib.mkIf config.mailserver.debug "debugLevel = 4";
}
