#  nixos-mailserver: a simple mail server
#  Copyright (C) 2017  Brian Olsen
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mailserver;

  dkimUser = config.services.opendkim.user;
  dkimGroup = config.services.opendkim.group;

  createDomainDkimCert = dom:
    let
      dkim_key = "${cfg.dkimKeyDirectory}/${dom}.${cfg.dkimSelector}.key";
      dkim_txt = "${cfg.dkimKeyDirectory}/${dom}.${cfg.dkimSelector}.txt";
    in
        ''
          if [ ! -f "${dkim_key}" ]
          then
              ${pkgs.opendkim}/bin/opendkim-genkey -s "${cfg.dkimSelector}" \
                                                   -d "${dom}" \
                                                   --bits="${toString cfg.dkimKeyBits}" \
                                                   --directory="${cfg.dkimKeyDirectory}"
              mv "${cfg.dkimKeyDirectory}/${cfg.dkimSelector}.private" "${dkim_key}"
              mv "${cfg.dkimKeyDirectory}/${cfg.dkimSelector}.txt" "${dkim_txt}"
              echo "Generated key for domain ${dom} selector ${cfg.dkimSelector}"
          fi
        '';
  createAllCerts = lib.concatStringsSep "\n" (map createDomainDkimCert cfg.domains);

  keyTable = pkgs.writeText "opendkim-KeyTable"
    (lib.concatStringsSep "\n" (lib.flip map cfg.domains
      (dom: "${dom} ${dom}:${cfg.dkimSelector}:${cfg.dkimKeyDirectory}/${dom}.${cfg.dkimSelector}.key")));
  signingTable = pkgs.writeText "opendkim-SigningTable"
    (lib.concatStringsSep "\n" (lib.flip map cfg.domains (dom: "${dom} ${dom}")));

  dkim = config.services.opendkim;
  args = [ "-f" "-l" ] ++ lib.optionals (dkim.configFile != null) [ "-x" dkim.configFile ];
in
{
    config = mkIf (cfg.dkimSigning && cfg.enable) {
      services.opendkim = {
        enable = true;
        selector = cfg.dkimSelector;
        keyPath = cfg.dkimKeyDirectory;
        domains = "csl:${builtins.concatStringsSep "," cfg.domains}";
        configFile = pkgs.writeText "opendkim.conf" (''
          Canonicalization ${cfg.dkimHeaderCanonicalization}/${cfg.dkimBodyCanonicalization}
          UMask 0002
          Socket ${dkim.socket}
          KeyTable file:${keyTable}
          SigningTable file:${signingTable}
        '' + (lib.optionalString cfg.debug ''
          Syslog yes
          SyslogSuccess yes
          LogWhy yes
        ''));
      };

      users.users = optionalAttrs (config.services.postfix.user == "postfix") {
        postfix.extraGroups = [ "${dkimGroup}" ];
      };
      systemd.services.opendkim = {
        preStart = lib.mkForce createAllCerts;
        serviceConfig = {
          ExecStart = lib.mkForce "${pkgs.opendkim}/bin/opendkim ${escapeShellArgs args}";
          PermissionsStartOnly = lib.mkForce false;
        };
      };
      systemd.tmpfiles.rules = [
        "d '${cfg.dkimKeyDirectory}' - ${dkimUser} ${dkimGroup} - -"
      ];
    };
}
