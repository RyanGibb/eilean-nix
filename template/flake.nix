{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    eilean.url = "github:RyanGibb/eilean-nix/main";
    eilean.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, eilean, ... }@inputs:
    let hostname = "eilean";
    in rec {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        system = null;
        pkgs = null;
        modules = [
          ./configuration.nix
          eilean.nixosModules.default
          {
            networking.hostName = hostname;
            # pin nix command's nixpkgs flake to the system flake to avoid unnecessary downloads
            nix.registry.nixpkgs.flake = nixpkgs;
            # record git revision (can be queried with `nixos-version --json)
            system.configurationRevision =
              nixpkgs.lib.mkIf (self ? rev) self.rev;
          }
        ];
      };
    };
}
