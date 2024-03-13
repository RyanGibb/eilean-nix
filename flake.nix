{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosModules.default = {
      imports = [
        ./modules/default.nix
        ({ config, ... }: {
          nixpkgs.overlays = [ (final: prev: {
            mautrix-meta = (prev.callPackage ./pkgs/mautrix-meta.nix { });
          }) ];
        })
      ];
    };
    defaultTemplate.path = ./template;
  };
}
