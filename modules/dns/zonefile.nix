{
  pkgs,
  config,
  lib,
  zonename,
  zone,
  ...
}:

pkgs.writeTextFile {
  name = "zonefile-${zonename}";
  destination = "/${zonename}";
  text = ''
    $ORIGIN ${zonename}.
    $TTL ${builtins.toString zone.ttl}
    @ IN SOA ${zone.soa.ns} ${zone.soa.email} (
      ${builtins.toString zone.soa.serial}
      ${builtins.toString zone.soa.refresh}
      ${builtins.toString zone.soa.retry}
      ${builtins.toString zone.soa.expire}
      ${builtins.toString zone.soa.negativeCacheTtl}
    )
    ${
      lib.strings.concatStringsSep "\n"
        (builtins.map (rr: "${rr.name} IN ${builtins.toString rr.ttl} ${rr.type} ${rr.data}") zone.records)
    }
  '';
}
