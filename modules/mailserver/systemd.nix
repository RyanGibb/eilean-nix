#  nixos-mailserver: a simple mail server
#  Copyright (C) 2016-2018  Robin Raymond
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

{ config, pkgs, lib, ... }:

let
  cfg = config.mailserver;
  certificatesDeps =
    if cfg.certificateScheme == 1 then
      []
    else if cfg.certificateScheme == 2 then
      [ "mailserver-selfsigned-certificate.service" ]
    else
      [ "acme-finished-${cfg.fqdn}.target" ];
in
{
  config = with cfg; lib.mkIf enable {
    # Create self signed certificate
    systemd.services.mailserver-selfsigned-certificate = lib.mkIf (cfg.certificateScheme == 2) {
      after = [ "local-fs.target" ];
      script = ''
        # Create certificates if they do not exist yet
        dir="${cfg.certificateDirectory}"
        fqdn="${cfg.fqdn}"
        [[ $fqdn == /* ]] && fqdn=$(< "$fqdn")
        key="$dir/key-${cfg.fqdn}.pem";
        cert="$dir/cert-${cfg.fqdn}.pem";

        if [[ ! -f $key || ! -f $cert ]]; then
            mkdir -p "${cfg.certificateDirectory}"
            (umask 077; "${pkgs.openssl}/bin/openssl" genrsa -out "$key" 2048) &&
                "${pkgs.openssl}/bin/openssl" req -new -key "$key" -x509 -subj "/CN=$fqdn" \
                        -days 3650 -out "$cert"
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        PrivateTmp = true;
      };
    };

    # Create maildir folder before dovecot startup
    systemd.services.dovecot2 = {
      wants = certificatesDeps;
      after = certificatesDeps;
      preStart = let
        directories = lib.strings.escapeShellArgs (
          [ mailDirectory ]
          ++ lib.optional (cfg.indexDir != null) cfg.indexDir
        );
      in ''
        # Create mail directory and set permissions. See
        # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>.
        mkdir -p ${directories}
        chgrp "${vmailGroupName}" ${directories}
        chmod 02770 ${directories}
      '';
    };

    # Postfix requires dovecot lmtp socket, dovecot auth socket and certificate to work
    systemd.services.postfix = {
      wants = certificatesDeps;
      after = [ "dovecot2.service" ]
        ++ lib.optional cfg.dkimSigning "opendkim.service"
        ++ certificatesDeps;
      requires = [ "dovecot2.service" ]
        ++ lib.optional cfg.dkimSigning "opendkim.service";
    };
  };
}
