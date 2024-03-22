{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-mailserver.url = "github:RyanGibb/nixos-mailserver/fork-23.11";
  };

  outputs = { self, nixpkgs, nixos-mailserver, ... }: rec {
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        manpage = import ./man { inherit pkgs system nixos-mailserver; };
      });

    nixosModules.default = {
      imports = [
        ./modules/default.nix
        nixos-mailserver.nixosModule
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
