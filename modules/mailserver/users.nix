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

with config.mailserver;

let
  vmail_user = {
    name = vmailUserName;
    isSystemUser = true;
    uid = vmailUID;
    home = mailDirectory;
    createHome = true;
    group = vmailGroupName;
  };


  virtualMailUsersActivationScript = pkgs.writeScript "activate-virtual-mail-users" ''
    #!${pkgs.stdenv.shell}

    set -euo pipefail

    # Create directory to store user sieve scripts if it doesn't exist
    if (! test -d "${sieveDirectory}"); then
      mkdir "${sieveDirectory}"
      chown "${vmailUserName}:${vmailGroupName}" "${sieveDirectory}"
      chmod 770 "${sieveDirectory}"
    fi

    # Copy user's sieve script to the correct location (if it exists).  If it
    # is null, remove the file.
    ${lib.concatMapStringsSep "\n" ({ name, sieveScript }:
      if lib.isString sieveScript then ''
        if (! test -d "${sieveDirectory}/${name}"); then
          mkdir -p "${sieveDirectory}/${name}"
          chown "${vmailUserName}:${vmailGroupName}" "${sieveDirectory}/${name}"
          chmod 770 "${sieveDirectory}/${name}"
        fi
        cat << 'EOF' > "${sieveDirectory}/${name}/default.sieve"
        ${sieveScript}
        EOF
        chown "${vmailUserName}:${vmailGroupName}" "${sieveDirectory}/${name}/default.sieve"
      '' else ''
        if (test -f "${sieveDirectory}/${name}/default.sieve"); then
          rm "${sieveDirectory}/${name}/default.sieve"
        fi
        if (test -f "${sieveDirectory}/${name}.svbin"); then
          rm "${sieveDirectory}/${name}/default.svbin"
        fi
      '') (map (user: { inherit (user) name sieveScript; })
            (lib.attrValues loginAccounts))}
  '';
in {
  config = lib.mkIf enable {
    # assert that all accounts provide a password
    assertions = (map (acct: {
      assertion = (acct.hashedPassword != null || acct.hashedPasswordFile != null);
      message = "${acct.name} must provide either a hashed password or a password hash file";
    }) (lib.attrValues loginAccounts));

    # warn for accounts that specify both password and file
    warnings = (map
      (acct: "${acct.name} specifies both a password hash and hash file; hash file will be used")
      (lib.filter
        (acct: (acct.hashedPassword != null && acct.hashedPasswordFile != null))
        (lib.attrValues loginAccounts)));

    # set the vmail gid to a specific value
    users.groups = {
      "${vmailGroupName}" = { gid = vmailUID; };
    };

    # define all users
    users.users = {
      "${vmail_user.name}" = lib.mkForce vmail_user;
    };

    systemd.services.activate-virtual-mail-users = {
      wantedBy = [ "multi-user.target" ];
      before = [ "dovecot2.service" ];
      serviceConfig = {
        ExecStart = virtualMailUsersActivationScript;
      };
      enable = true;
    };
  };
}
