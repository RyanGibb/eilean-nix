{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixos-mailserver.url = "gitlab:RyanGibb/nixos-mailserver/fork-24.05";
    eon.url = "github:RyanGibb/eon";
    eon.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-mailserver, eon, ... }: rec {
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in { manpage = import ./man { inherit pkgs system nixos-mailserver; }; });

    nixosModules.default = {
      imports = [
        ./modules/default.nix
        nixos-mailserver.nixosModule
        eon.nixosModules.default
        eon.nixosModules.acme
        ({ pkgs, config, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              mautrix-meta = (prev.callPackage ./pkgs/mautrix-meta.nix { });
            })
          ];
        })
      ];
    };
    defaultTemplate.path = ./template;

    formatter = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
      (system: nixpkgs.legacyPackages.${system}.nixfmt);
  };
}
