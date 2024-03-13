{ pkgs, system, ... }:

with pkgs;
let
    optionsDoc =
      let
        eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
          inherit system;
          modules = [
            ../modules/default.nix
          ];
        };
      in pkgs.nixosOptionsDoc {
        options = eval.options;
        # TODO make sure all options have descriptions
        warningsAreErrors = false;
      };

  # Generate the `man eliean.nix` package
  eilean-configuration-manual =
    runCommand "eilean-reference-manpage"
    { nativeBuildInputs = [
        buildPackages.installShellFiles
        buildPackages.nixos-render-docs
      ];
      allowedReferences = [ "out" ];
    }
    ''
      # Generate manpages.
      mkdir -p $out/share/man/man5
      # filter to only eilean options
      cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json \
        | ${pkgs.jq}/bin/jq 'with_entries(select(.key | test("^eilean")))' \
        > eilean-options.json
      nixos-render-docs -j $NIX_BUILD_CORES options manpage \
        --revision dev \
        --header ${./eilean-configuration-nix-header.5} \
        --footer ${./eilean-configuration-nix-footer.5} \
        eilean-options.json \
        $out/share/man/man5/eilean-configuration.nix.5
    '';
in eilean-configuration-manual
