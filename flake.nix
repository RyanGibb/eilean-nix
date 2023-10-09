{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosModules.default = {
      imports = [ ./modules/default.nix ];
    };
    defaultTemplate.path = ./template;
  };
}
