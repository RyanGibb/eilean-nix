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

with (import ./common.nix { inherit config pkgs lib; });

let
  cfg = config.mailserver;

  passwdDir = "/run/dovecot2";
  passwdFile = "${passwdDir}/passwd";

  bool2int = x: if x then "1" else "0";

  maildirLayoutAppendix = lib.optionalString cfg.useFsLayout ":LAYOUT=fs";

  # maildir in format "/${domain}/${user}"
  dovecotMaildir =
    "maildir:${cfg.mailDirectory}/%d/%n${maildirLayoutAppendix}"
    + (lib.optionalString (cfg.indexDir != null)
       ":INDEX=${cfg.indexDir}/%d/%n"
      );

  postfixCfg = config.services.postfix;
  dovecot2Cfg = config.services.dovecot2;

  stateDir = "/var/lib/dovecot";

  pipeBin = pkgs.stdenv.mkDerivation {
    name = "pipe_bin";
    src = ./dovecot/pipe_bin;
    buildInputs = with pkgs; [ makeWrapper coreutils bash rspamd ];
    buildCommand = ''
      mkdir -p $out/pipe/bin
      cp $src/* $out/pipe/bin/
      chmod a+x $out/pipe/bin/*
      patchShebangs $out/pipe/bin

      for file in $out/pipe/bin/*; do
        wrapProgram $file \
          --set PATH "${pkgs.coreutils}/bin:${pkgs.rspamd}/bin"
      done
    '';
  };

  genPasswdScript = pkgs.writeScript "generate-password-file" ''
    #!${pkgs.stdenv.shell}

    set -euo pipefail

    if (! test -d "${passwdDir}"); then
      mkdir "${passwdDir}"
      chmod 755 "${passwdDir}"
    fi

    for f in ${builtins.toString (lib.mapAttrsToList (name: value: passwordFiles."${name}") cfg.loginAccounts)}; do
      if [ ! -f "$f" ]; then
        echo "Expected password hash file $f does not exist!"
        exit 1
      fi
    done

    cat <<EOF > ${passwdFile}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
      "${name}:${"$(head -n 1 ${passwordFiles."${name}"})"}:${builtins.toString cfg.vmailUID}:${builtins.toString cfg.vmailUID}::${cfg.mailDirectory}:/run/current-system/sw/bin/nologin:"
        + (if lib.isString value.quota
              then "userdb_quota_rule=*:storage=${value.quota}"
              else "")
    ) cfg.loginAccounts)}
    EOF

    chmod 600 ${passwdFile}
  '';

  junkMailboxes = builtins.attrNames (lib.filterAttrs (n: v: v ? "specialUse" && v.specialUse == "Junk") cfg.mailboxes);
  junkMailboxNumber = builtins.length junkMailboxes;
  # The assertion garantees there is exactly one Junk mailbox.
  junkMailboxName = if junkMailboxNumber == 1 then builtins.elemAt junkMailboxes 0 else "";

in
{
  config = with cfg; lib.mkIf enable {
    assertions = [
      {
        assertion = junkMailboxNumber == 1;
        message = "nixos-mailserver requires exactly one dovecot mailbox with the 'special use' flag set to 'Junk' (${builtins.toString junkMailboxNumber} have been found)";
      }
    ];

    services.dovecot2 = {
      enable = true;
      enableImap = enableImap || enableImapSsl;
      enablePop3 = enablePop3 || enablePop3Ssl;
      enablePAM = false;
      enableQuota = true;
      mailGroup = vmailGroupName;
      mailUser = vmailUserName;
      mailLocation = dovecotMaildir;
      sslServerCert = certificatePath;
      sslServerKey = keyPath;
      enableLmtp = true;
      modules = [ pkgs.dovecot_pigeonhole ] ++ (lib.optional cfg.fullTextSearch.enable pkgs.dovecot_fts_xapian );
      mailPlugins.globally.enable = lib.optionals cfg.fullTextSearch.enable [ "fts" "fts_xapian" ];
      protocols = lib.optional cfg.enableManageSieve "sieve";

      sieveScripts = {
        after = builtins.toFile "spam.sieve" ''
          require "fileinto";

          if header :is "X-Spam" "Yes" {
              fileinto "${junkMailboxName}";
              stop;
          }
        '';
      };

      mailboxes = cfg.mailboxes;

      extraConfig = ''
        #Extra Config
        ${lib.optionalString debug ''
          mail_debug = yes
          auth_debug = yes
          verbose_ssl = yes
        ''}

        ${lib.optionalString (cfg.enableImap || cfg.enableImapSsl) ''
          service imap-login {
            inet_listener imap {
              ${if cfg.enableImap then ''
                port = 143
              '' else ''
                # see https://dovecot.org/pipermail/dovecot/2010-March/047479.html
                port = 0
              ''}
            }
            inet_listener imaps {
              ${if cfg.enableImapSsl then ''
                port = 993
                ssl = yes
              '' else ''
                # see https://dovecot.org/pipermail/dovecot/2010-March/047479.html
                port = 0
              ''}
            }
          }
        ''}
        ${lib.optionalString (cfg.enablePop3 || cfg.enablePop3Ssl) ''
          service pop3-login {
            inet_listener pop3 {
              ${if cfg.enablePop3 then ''
                port = 110
              '' else ''
                # see https://dovecot.org/pipermail/dovecot/2010-March/047479.html
                port = 0
              ''}
            }
            inet_listener pop3s {
              ${if cfg.enablePop3Ssl then ''
                port = 995
                ssl = yes
              '' else ''
                # see https://dovecot.org/pipermail/dovecot/2010-March/047479.html
                port = 0
              ''}
            }
          }
        ''}

        protocol imap {
          mail_max_userip_connections = ${toString cfg.maxConnectionsPerUser}
          mail_plugins = $mail_plugins imap_sieve
        }

        protocol pop3 {
          mail_max_userip_connections = ${toString cfg.maxConnectionsPerUser}
        }

        mail_access_groups = ${vmailGroupName}
        ssl = required
        ssl_min_protocol = TLSv1.2
        ssl_prefer_server_ciphers = yes

        service lmtp {
          unix_listener dovecot-lmtp {
            group = ${postfixCfg.group}
            mode = 0600
            user = ${postfixCfg.user}
          }
        }

        recipient_delimiter = ${cfg.recipientDelimiter}
        lmtp_save_to_detail_mailbox = ${cfg.lmtpSaveToDetailMailbox}

        protocol lmtp {
          mail_plugins = $mail_plugins sieve
        }

        passdb {
          driver = passwd-file
          args = ${passwdFile}
        }

        userdb {
          driver = passwd-file
          args = ${passwdFile}
        }

        service auth {
          unix_listener auth {
            mode = 0660
            user = ${postfixCfg.user}
            group = ${postfixCfg.group}
          }
        }

        auth_mechanisms = plain login

        namespace inbox {
          separator = ${cfg.hierarchySeparator}
          inbox = yes
        }

        plugin {
          sieve_plugins = sieve_imapsieve sieve_extprograms
          sieve = file:${cfg.sieveDirectory}/%u/scripts;active=${cfg.sieveDirectory}/%u/active.sieve
          sieve_default = file:${cfg.sieveDirectory}/%u/default.sieve
          sieve_default_name = default

          # From elsewhere to Spam folder
          imapsieve_mailbox1_name = ${junkMailboxName}
          imapsieve_mailbox1_causes = COPY
          imapsieve_mailbox1_before = file:${stateDir}/imap_sieve/report-spam.sieve

          # From Spam folder to elsewhere
          imapsieve_mailbox2_name = *
          imapsieve_mailbox2_from = ${junkMailboxName}
          imapsieve_mailbox2_causes = COPY
          imapsieve_mailbox2_before = file:${stateDir}/imap_sieve/report-ham.sieve

          sieve_pipe_bin_dir = ${pipeBin}/pipe/bin

          sieve_global_extensions = +vnd.dovecot.pipe +vnd.dovecot.environment
        }

        ${lib.optionalString cfg.fullTextSearch.enable ''
        plugin {
          plugin = fts fts_xapian
          fts = xapian
          fts_xapian = partial=${toString cfg.fullTextSearch.minSize} full=${toString cfg.fullTextSearch.maxSize} attachments=${bool2int cfg.fullTextSearch.indexAttachments} verbose=${bool2int cfg.debug}

          fts_autoindex = ${if cfg.fullTextSearch.autoIndex then "yes" else "no"}

          ${lib.strings.concatImapStringsSep "\n" (n: x: "fts_autoindex_exclude${if n==1 then "" else toString n} = ${x}") cfg.fullTextSearch.autoIndexExclude}

          fts_enforced = ${cfg.fullTextSearch.enforced}
        }

        ${lib.optionalString (cfg.fullTextSearch.memoryLimit != null) ''
        service indexer-worker {
          vsz_limit = ${toString (cfg.fullTextSearch.memoryLimit*1024*1024)}
        }
        ''}
        ''}

        lda_mailbox_autosubscribe = yes
        lda_mailbox_autocreate = yes
      '';
    };

    systemd.services.dovecot2 = {
      preStart = ''
        ${genPasswdScript}
        rm -rf '${stateDir}/imap_sieve'
        mkdir '${stateDir}/imap_sieve'
        cp -p "${./dovecot/imap_sieve}"/*.sieve '${stateDir}/imap_sieve/'
        for k in "${stateDir}/imap_sieve"/*.sieve ; do
          ${pkgs.dovecot_pigeonhole}/bin/sievec "$k"
        done
        chown -R '${dovecot2Cfg.mailUser}:${dovecot2Cfg.mailGroup}' '${stateDir}/imap_sieve'
      '';
    };

    systemd.services.postfix.restartTriggers = [ genPasswdScript ];

    systemd.services.dovecot-fts-xapian-optimize = lib.mkIf (cfg.fullTextSearch.enable && cfg.fullTextSearch.maintenance.enable) {
      description = "Optimize dovecot indices for fts_xapian";
      requisite = [ "dovecot2.service" ];
      after = [ "dovecot2.service" ];
      startAt = cfg.fullTextSearch.maintenance.onCalendar;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.dovecot}/bin/doveadm fts optimize -A";
        PrivateDevices = true;
        PrivateNetwork = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectSystem = true;
        PrivateTmp = true;
      };
    };
    systemd.timers.dovecot-fts-xapian-optimize = lib.mkIf (cfg.fullTextSearch.enable && cfg.fullTextSearch.maintenance.enable && cfg.fullTextSearch.maintenance.randomizedDelaySec != 0) {
      timerConfig = {
        RandomizedDelaySec = cfg.fullTextSearch.maintenance.randomizedDelaySec;
      };
    };
  };
}
