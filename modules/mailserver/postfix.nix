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
  inherit (lib.strings) concatStringsSep;
  cfg = config.mailserver;

  # Merge several lookup tables. A lookup table is a attribute set where
  # - the key is an address (user@example.com) or a domain (@example.com)
  # - the value is a list of addresses
  mergeLookupTables = tables: lib.zipAttrsWith (n: v: lib.flatten v) tables;

  # valiases_postfix :: Map String [String]
  valiases_postfix = mergeLookupTables (lib.flatten (lib.mapAttrsToList
    (name: value:
      let to = name;
      in map (from: {"${from}" = to;}) (value.aliases ++ lib.singleton name))
    cfg.loginAccounts));

  # catchAllPostfix :: Map String [String]
  catchAllPostfix =  mergeLookupTables (lib.flatten (lib.mapAttrsToList
    (name: value:
      let to = name;
      in map (from: {"@${from}" = to;}) value.catchAll)
      cfg.loginAccounts));

  # all_valiases_postfix :: Map String [String]
  all_valiases_postfix = mergeLookupTables [valiases_postfix extra_valiases_postfix];

  # attrsToLookupTable :: Map String (Either String [ String ]) -> Map String [String]
  attrsToLookupTable = aliases: let
    lookupTables = lib.mapAttrsToList (from: to: {"${from}" = to;}) aliases;
  in mergeLookupTables lookupTables;

  # extra_valiases_postfix :: Map String [String]
  extra_valiases_postfix = attrsToLookupTable cfg.extraVirtualAliases;

  # forwards :: Map String [String]
  forwards = attrsToLookupTable cfg.forwards;

  # lookupTableToString :: Map String [String] -> String
  lookupTableToString = attrs: let
    valueToString = value: lib.concatStringsSep ", " value;
  in lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name} ${valueToString value}") attrs);

  # valiases_file :: Path
  valiases_file = let
    content = lookupTableToString (mergeLookupTables [all_valiases_postfix catchAllPostfix]);
  in builtins.toFile "valias" content;

  # denied_recipients_postfix :: [ String ]
  denied_recipients_postfix = (map
    (acct: "${acct.name} REJECT ${acct.sendOnlyRejectMessage}")
    (lib.filter (acct: acct.sendOnly) (lib.attrValues cfg.loginAccounts)));
  denied_recipients_file = builtins.toFile "denied_recipients" (lib.concatStringsSep "\n" denied_recipients_postfix);

  reject_senders_postfix = (map
    (sender:
      "${sender} REJECT")
    (cfg.rejectSender));
  reject_senders_file = builtins.toFile "reject_senders" (lib.concatStringsSep "\n" (reject_senders_postfix))  ;

  reject_recipients_postfix = (map
    (recipient:
      "${recipient} REJECT")
    (cfg.rejectRecipients));
  # rejectRecipients :: [ Path ]
  reject_recipients_file = builtins.toFile "reject_recipients" (lib.concatStringsSep "\n" (reject_recipients_postfix))  ;

  # vhosts_file :: Path
  vhosts_file = builtins.toFile "vhosts" (concatStringsSep "\n" cfg.domains);

  # vaccounts_file :: Path
  # see
  # https://blog.grimneko.de/2011/12/24/a-bunch-of-tips-for-improving-your-postfix-setup/
  # for details on how this file looks. By using the same file as valiases,
  # every alias is owned (uniquely) by its user.
  # The user's own address is already in all_valiases_postfix.
  vaccounts_file = builtins.toFile "vaccounts" (lookupTableToString all_valiases_postfix);

  submissionHeaderCleanupRules = pkgs.writeText "submission_header_cleanup_rules" (''
     # Removes sensitive headers from mails handed in via the submission port.
     # See https://thomas-leister.de/mailserver-debian-stretch/
     # Uses "pcre" style regex.

     /^Received:/            IGNORE
     /^X-Originating-IP:/    IGNORE
     /^X-Mailer:/            IGNORE
     /^User-Agent:/          IGNORE
     /^X-Enigmail:/          IGNORE
  '' + lib.optionalString cfg.rewriteMessageId ''

     # Replaces the user submitted hostname with the server's FQDN to hide the
     # user's host or network.

     /^Message-ID:\s+<(.*?)@.*?>/ REPLACE Message-ID: <$1@${cfg.fqdn}>
  '');

  inetSocket = addr: port: "inet:[${toString port}@${addr}]";
  unixSocket = sock: "unix:${sock}";

  smtpdMilters =
   (lib.optional cfg.dkimSigning "unix:/run/opendkim/opendkim.sock")
   ++ [ "unix:/run/rspamd/rspamd-milter.sock" ];

  policyd-spf = pkgs.writeText "policyd-spf.conf" cfg.policydSPFExtraConfig;

  mappedFile = name: "hash:/var/lib/postfix/conf/${name}";

  submissionOptions =
    {
      smtpd_tls_security_level = "encrypt";
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "/run/dovecot2/auth";
      smtpd_sasl_security_options = "noanonymous";
      smtpd_sasl_local_domain = "$myhostname";
      smtpd_client_restrictions = "permit_sasl_authenticated,reject";
      smtpd_sender_login_maps = "hash:/etc/postfix/vaccounts";
      smtpd_sender_restrictions = "reject_sender_login_mismatch";
      smtpd_recipient_restrictions = "reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject";
      cleanup_service_name = "submission-header-cleanup";
    };
in
{
  config = with cfg; lib.mkIf enable {

    services.postfix = {
      enable = true;
      hostname = "${sendingFqdn}";
      networksStyle = "host";
      mapFiles."valias" = valiases_file;
      mapFiles."vaccounts" = vaccounts_file;
      mapFiles."denied_recipients" = denied_recipients_file;
      mapFiles."reject_senders" = reject_senders_file;
      mapFiles."reject_recipients" = reject_recipients_file;
      sslCert = certificatePath;
      sslKey = keyPath;
      enableSubmission = cfg.enableSubmission;
      enableSubmissions = cfg.enableSubmissionSsl;
      virtual = lookupTableToString (mergeLookupTables [all_valiases_postfix catchAllPostfix forwards]);

      config = {
        # Extra Config
        mydestination = "";
        recipient_delimiter = cfg.recipientDelimiter;
        smtpd_banner = "${fqdn} ESMTP NO UCE";
        disable_vrfy_command = true;
        message_size_limit = toString cfg.messageSizeLimit;

        # virtual mail system
        virtual_uid_maps = "static:5000";
        virtual_gid_maps = "static:5000";
        virtual_mailbox_base = mailDirectory;
        virtual_mailbox_domains = vhosts_file;
        virtual_mailbox_maps = mappedFile "valias";
        virtual_transport = "lmtp:unix:/run/dovecot2/dovecot-lmtp";
        # Avoid leakage of X-Original-To, X-Delivered-To headers between recipients
        lmtp_destination_recipient_limit = "1";

        # sasl with dovecot
        smtpd_sasl_type = "dovecot";
        smtpd_sasl_path = "/run/dovecot2/auth";
        smtpd_sasl_auth_enable = true;
        smtpd_relay_restrictions = [
          "permit_mynetworks" "permit_sasl_authenticated" "reject_unauth_destination"
        ];

        policy-spf_time_limit = "3600s";

        # reject selected senders
        smtpd_sender_restrictions = [
          "check_sender_access ${mappedFile "reject_senders"}"
        ];

        # quota and spf checking
        smtpd_recipient_restrictions = [
          "check_recipient_access ${mappedFile "denied_recipients"}"
          "check_recipient_access ${mappedFile "reject_recipients"}"
          "check_policy_service inet:localhost:12340"
          "check_policy_service unix:private/policy-spf"
        ];

        # TLS settings, inspired by https://github.com/jeaye/nix-files
        # Submission by mail clients is handled in submissionOptions
        smtpd_tls_security_level = "may";

        # strong might suffice and is computationally less expensive
        smtpd_tls_eecdh_grade = "ultra";

        # Disable obselete protocols
        smtpd_tls_protocols = "TLSv1.3, TLSv1.2, TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
        smtp_tls_protocols = "TLSv1.3, TLSv1.2, TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
        smtpd_tls_mandatory_protocols = "TLSv1.3, TLSv1.2, TLSv1.1, !TLSv1, !SSLv2, !SSLv3";
        smtp_tls_mandatory_protocols = "TLSv1.3, TLSv1.2, TLSv1.1, !TLSv1, !SSLv2, !SSLv3";

        smtp_tls_ciphers = "high";
        smtpd_tls_ciphers = "high";
        smtp_tls_mandatory_ciphers = "high";
        smtpd_tls_mandatory_ciphers = "high";

        # Disable deprecated ciphers
        smtpd_tls_mandatory_exclude_ciphers = "MD5, DES, ADH, RC4, PSD, SRP, 3DES, eNULL, aNULL";
        smtpd_tls_exclude_ciphers = "MD5, DES, ADH, RC4, PSD, SRP, 3DES, eNULL, aNULL";
        smtp_tls_mandatory_exclude_ciphers = "MD5, DES, ADH, RC4, PSD, SRP, 3DES, eNULL, aNULL";
        smtp_tls_exclude_ciphers = "MD5, DES, ADH, RC4, PSD, SRP, 3DES, eNULL, aNULL";

        tls_preempt_cipherlist = true;

        # Allowing AUTH on a non encrypted connection poses a security risk
        smtpd_tls_auth_only = true;
        # Log only a summary message on TLS handshake completion
        smtpd_tls_loglevel = "1";

        # Configure a non blocking source of randomness
        tls_random_source = "dev:/dev/urandom";

        smtpd_milters = smtpdMilters;
        non_smtpd_milters = lib.mkIf cfg.dkimSigning ["unix:/run/opendkim/opendkim.sock"];
        milter_protocol = "6";
        milter_mail_macros = "i {mail_addr} {client_addr} {client_name} {auth_type} {auth_authen} {auth_author} {mail_addr} {mail_host} {mail_mailer}";

      };

      submissionOptions = submissionOptions;
      submissionsOptions = submissionOptions;

      masterConfig = {
        "lmtp" = {
          # Add headers when delivering, see http://www.postfix.org/smtp.8.html
          # D => Delivered-To, O => X-Original-To, R => Return-Path
          args = [ "flags=O" ];
        };
        "policy-spf" = {
          type = "unix";
          privileged = true;
          chroot = false;
          command = "spawn";
          args = [ "user=nobody" "argv=${pkgs.pypolicyd-spf}/bin/policyd-spf" "${policyd-spf}"];
        };
        "submission-header-cleanup" = {
          type = "unix";
          private = false;
          chroot = false;
          maxproc = 0;
          command = "cleanup";
          args = ["-o" "header_checks=pcre:${submissionHeaderCleanupRules}"];
        };
      };
    };
  };
}
