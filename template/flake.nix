{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    eilean.url ="github:RyanGibb/eilean-nix/main";
  };

  outputs = { self, nixpkgs, eilean, ... }@inputs: rec {
    nixosConfigurations.server =
      let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
        modules = [
            ./default.nix
            eilean.nixosModules.default
            {
              networking.hostName = "server";
              # pin nix command's nixpkgs flake to the system flake to avoid unnecessary downloads
              nix.registry.nixpkgs.flake = nixpkgs;
              system.stateVersion = "22.11";
              # record git revision (can be queried with `nixos-version --json)
              system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
            }
          ];
        };
      };
  }
