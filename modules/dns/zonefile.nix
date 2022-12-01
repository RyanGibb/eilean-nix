{ pkgs, config, lib, ... }:

let cfg = config.dns; in pkgs.writeTextFile {
  name = "zonefile";
  text = ''
    $ORIGIN ${cfg.domain}.
    $TTL ${builtins.toString cfg.ttl}
    @ IN SOA ${cfg.soa.ns} ${cfg.soa.email} (
      ${builtins.toString cfg.soa.serial}
      ${builtins.toString cfg.soa.refresh}
      ${builtins.toString cfg.soa.retry}
      ${builtins.toString cfg.soa.expire}
      ${builtins.toString cfg.soa.negativeCacheTtl}
    )
    ${
      lib.strings.concatStringsSep "\n"
        (builtins.map (rr: "${rr.name} IN ${builtins.toString rr.ttl} ${rr.type} ${rr.data}") cfg.records)
    }
  '';
}
