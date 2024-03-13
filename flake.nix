{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: rec {
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        manpage = import ./man { inherit pkgs system; };
      });

    nixosModules.default = {
      imports = [
        ./modules/default.nix
        ({ pkgs, config, ... }: {
          nixpkgs.overlays = [ (final: prev: {
            mautrix-meta = (prev.callPackage ./pkgs/mautrix-meta.nix { });
          }) ];
        })
      ];
    };
    defaultTemplate.path = ./template;
  };
}
