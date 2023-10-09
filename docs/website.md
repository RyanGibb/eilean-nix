
### Hosting a website

To host a simple static website stored at `/var/www` at your domain, you can create a `website.nix`:

```
{ config, ... }:

{
  services.nginx.virtualHosts."${config.networking.domain}" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/www";
  };
}
```

And import it in `configuration.nix`.

If you want to build your website with Nix it's possible to add it as a reproducible package.

```
{ config, pkgs, ... }:

{
  services.nginx.virtualHosts."${config.networking.domain}" = {
    enableACME = true;
    forceSSL = true;
    root =
      let website = pkgs.stdenv.mkDerivation rec {
        name = "website";
      
        src = pkgs.stdenv.fetchFromGitHub {
          owner = "<user>";
          repo = "website";
          rev = "<hash>";
          sha256 = "";
        };

        buildInputs = with pkgs [
          # dependencies
        ];

        installPhase = ''
          mkdir $out
          cp -r * $out
        '';
      };
    in website;
  };
}
```
