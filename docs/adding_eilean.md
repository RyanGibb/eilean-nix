
# Adding Eilean to an Existing NixOS System

If you already have a NixOS system and want to use Eilean you can add to your configuration.
Note this requires a flake-enabled system.

Add `github:RyanGibb/eilean-nix` as an input to your flake, and import `eilean.nixosModules.default`.
You should then be able to use the configuration options in `config.eilean`.
See [../template/flake.nix](../template/flake.nix) for an example.
