{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-26.05";
    eon.url = "github:RyanGibb/eon";

    eon.inputs.nixpkgs.follows = "nixpkgs";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      nixos-mailserver,
      eon,
      ...
    }:
    {
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          manpage = import ./man {
            inherit
              pkgs
              system
              nixos-mailserver
              eon
              ;
          };
        }
      );

      nixosModules.default = {
        imports = [
          ./modules/default.nix
          nixos-mailserver.nixosModule
          eon.nixosModules.default
          eon.nixosModules.acme
          {
            nixpkgs.overlays = [
              (final: prev: {
                mautrix-meta = (prev.callPackage ./pkgs/mautrix-meta.nix { });
              })
            ];
          }
        ];
      };
      templates.default = {
        path = ./template;
        description = "Eilean server configuration template";
      };

      formatter = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system: nixpkgs.legacyPackages.${system}.nixfmt
      );
    };
}
