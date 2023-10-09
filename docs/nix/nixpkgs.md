
### Nixpkgs

Nixpkgs^[ [github.com/nixos/nixpkgs](https://github.com/nixos/nixpkgs) ] is a large repository of software packaged in [Nix](./nix.md), where every package is a Nix derivation.
It also stores all the default [./NixOS](./nixos.md) modules.

There is also a command line package manager that installs packages from Nixpkgs, which is why people sometimes refer to Nix as a package manager.

While Nix, and therefore Nix package management, is primarily source-based (since derivations describe how to build software from source), binary deployment is an optimisation of this.
Since packages are built in isolation and entirely determined by their inputs, binaries can be transparently deployed by downloading them from a remote server instead of building the derivation locally.

Nix supports atomic upgrades and rollbacks.
The pointers to the new packages are only updated when the install succeeds.

Due to every


While Nixpkgs also has one global coherent package set, one can use multiple instances of Nixpkgs (i.e., channels) at once to support partial upgrades, as the Nix store allows multiple versions of a dependency to be stored.
This also supports atomic upgrades, as all the software's old versions can be kept until garbage collection.
